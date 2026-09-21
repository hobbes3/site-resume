import puppeteer from "puppeteer-core";
import path from "node:path";
import fs from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { build, preview } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(__dirname, "..");
const distDir = path.join(projectRoot, "dist");
const resumesDir = path.join(distDir, "resumes");
const reportsDir = path.join(distDir, "reports");

await build({ root: projectRoot });

await fs.mkdir(resumesDir, { recursive: true });
await fs.mkdir(reportsDir, { recursive: true });

// 1. Start local Vite preview server
const server = await preview({
  root: projectRoot,
  preview: {
    port: 4173,
    strictPort: true,
  },
});

const previewUrl = server.resolvedUrls.local[0] || "http://localhost:5173/";

const chromePath =
  process.platform === "darwin"
    ? "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    : "/usr/bin/google-chrome-stable";

const browser = await puppeteer.launch({
  executablePath: chromePath,
  args: [
    "--no-sandbox",
    "--disable-setuid-sandbox",
    "--allow-file-access-from-files",
  ],
});

try {
  const page = await browser.newPage();

  // Set default navigation timeout for this page (10,000 ms)
  page.setDefaultNavigationTimeout(10000);

  // Load preview page over HTTP
  await page.goto(previewUrl, { waitUntil: "networkidle0", timeout: 10000 });

  // Ensure fonts are completely loaded
  await page.evaluate(async () => {
    await document.fonts.load("16px Carlito");
    await document.fonts.ready;
  });

  // 2. Extract stylesheet content and resume markup
  const { inlineCss, resumeMarkup } = await page.evaluate(async () => {
    const stylePromises = Array.from(
      document.querySelectorAll('link[rel="stylesheet"]'),
    ).map(async (link) => {
      try {
        const response = await fetch(link.href);
        return await response.text();
      } catch {
        return "";
      }
    });

    const embeddedStyles = Array.from(document.querySelectorAll("style"))
      .map((style) => style.innerHTML)
      .join("\n");

    const fetchedStyles = (await Promise.all(stylePromises)).join("\n");

    const wrapper =
      document.querySelector("#resume-wrapper") ||
      document.querySelector("#resume");

    return {
      inlineCss: `${embeddedStyles}\n${fetchedStyles}`,
      resumeMarkup: wrapper ? wrapper.outerHTML : "",
    };
  });

  // Relative paths for the standalone saved HTML report
  const relativeCss = inlineCss.replace(
    /url\((['"]?)\/assets\//g,
    "url($1../assets/",
  );

  const htmlContent = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Resume</title>
  <style>
${relativeCss}
  </style>
</head>
<body>
  ${resumeMarkup}
</body>
</html>`;

  // Write isolated HTML report to disk for dist/reports/
  const htmlOutputPath = path.join(reportsDir, "hobbes3_resume_latest.html");
  await fs.writeFile(htmlOutputPath, htmlContent, "utf-8");
  console.log(`Successfully generated ${htmlOutputPath}`);

  // 3. For PDF generation, set isolated HTML content with absolute HTTP URLs
  const absoluteCss = inlineCss.replace(
    /url\((['"]?)\/assets\//g,
    `url($1${previewUrl}assets/`,
  );

  // Use domcontentloaded + explicit 10s timeout to prevent networkidle hangs
  await page.setContent(
    `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <style>${absoluteCss}</style>
</head>
<body>${resumeMarkup}</body>
</html>`,
    { waitUntil: "domcontentloaded", timeout: 10000 },
  );

  // Wait explicitly for Carlito font readiness in DOM
  await page.evaluate(async () => {
    await document.fonts.load("16px Carlito");
    await document.fonts.ready;
  });

  // 4. Generate clean single-page PDF
  const pdfOutputPath = path.join(resumesDir, "hobbes3_resume_latest.pdf");
  await page.pdf({
    path: pdfOutputPath,
    printBackground: true,
    displayHeaderFooter: false,
    preferCSSPageSize: true,
  });
  console.log(`Successfully generated ${pdfOutputPath}`);
} finally {
  await browser.close();
  await server.httpServer.close();
}
