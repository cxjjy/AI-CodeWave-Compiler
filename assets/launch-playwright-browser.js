const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');
const { chromium } = require('playwright');

function existingBrowserCandidates() {
  const candidates = [];
  const add = (name, executablePath) => {
    if (executablePath && fs.existsSync(executablePath) &&
        !candidates.some((item) => item.executablePath === executablePath)) {
      candidates.push({ name, executablePath });
    }
  };

  if (process.platform === 'win32') {
    add('Chrome', path.join(process.env.LOCALAPPDATA || '', 'Google/Chrome/Application/chrome.exe'));
    add('Chrome', path.join(process.env.PROGRAMFILES || '', 'Google/Chrome/Application/chrome.exe'));
    add('Chrome', path.join(process.env['PROGRAMFILES(X86)'] || '', 'Google/Chrome/Application/chrome.exe'));
    add('Edge', path.join(process.env.PROGRAMFILES || '', 'Microsoft/Edge/Application/msedge.exe'));
    add('Edge', path.join(process.env['PROGRAMFILES(X86)'] || '', 'Microsoft/Edge/Application/msedge.exe'));
    add('Edge', path.join(process.env.LOCALAPPDATA || '', 'Microsoft/Edge/Application/msedge.exe'));
  } else if (process.platform === 'darwin') {
    add('Chrome', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');
    add('Edge', '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge');
  } else {
    add('Chrome', '/usr/bin/google-chrome');
    add('Chrome', '/usr/bin/google-chrome-stable');
    add('Edge', '/usr/bin/microsoft-edge');
    add('Edge', '/usr/bin/microsoft-edge-stable');
  }

  return candidates;
}

async function launchPreferredBrowser(options = {}) {
  const launchOptions = { headless: true, ...options };

  for (const candidate of existingBrowserCandidates()) {
    try {
      const browser = await chromium.launch({
        ...launchOptions,
        executablePath: candidate.executablePath
      });
      console.log(`使用本机 ${candidate.name}：${candidate.executablePath}`);
      return browser;
    } catch (error) {
      console.warn(`本机 ${candidate.name} 无法用于自动化测试：${error.message}`);
    }
  }

  console.log('本机 Chrome/Edge 均不可用，正在安装 Playwright Chromium。');
  const npxCommand = process.platform === 'win32' ? 'npx.cmd' : 'npx';
  const install = spawnSync(npxCommand, ['--yes', 'playwright', 'install', 'chromium'], {
    stdio: 'inherit'
  });
  if (install.status !== 0) {
    throw new Error('Playwright Chromium 自动安装失败，请检查 npm 网络或代理配置。');
  }

  return chromium.launch(launchOptions);
}

module.exports = { launchPreferredBrowser };
