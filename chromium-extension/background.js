importScripts("config.js");

const region = globalThis.S3_CONSOLE_REGION;

chrome.omnibox.setDefaultSuggestion({
  description: "S3-Adresse in der AWS Console öffnen",
});

function consoleUrl(input) {
  const value = input.trim();
  const uri = /^s3:\/\//i.test(value) ? value : `s3://${value}`;
  const parsed = new URL(uri);

  if (parsed.protocol !== "s3:" || !parsed.hostname) {
    throw new Error("Expected s3://bucket/path");
  }

  const bucket = encodeURIComponent(decodeURIComponent(parsed.hostname));
  const key = parsed.pathname
    .replace(/^\/+/, "")
    .split("/")
    .map((segment) => encodeURIComponent(decodeURIComponent(segment)))
    .join("/");

  return (
    `https://${region}.console.aws.amazon.com/s3/buckets/${bucket}` +
    `?region=${encodeURIComponent(region)}` +
    `&prefix=${key}` +
    "&showversions=false"
  );
}

chrome.omnibox.onInputEntered.addListener((input, disposition) => {
  let url;
  try {
    url = consoleUrl(input);
  } catch (error) {
    console.error("Invalid S3 URI:", error);
    return;
  }

  switch (disposition) {
    case "newForegroundTab":
      chrome.tabs.create({ url, active: true });
      break;
    case "newBackgroundTab":
      chrome.tabs.create({ url, active: false });
      break;
    default:
      chrome.tabs.update({ url });
  }
});
