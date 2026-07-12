(async function () {
  const getAppHtmlUrl = '/simple_proxy/getAppHtml';

  try {
    const response = await fetch(getAppHtmlUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
    });

    if (!response.ok) {
      throw new Error('页面接口请求失败，HTTP 状态码：' + response.status);
    }

    const result = await response.json();
    const code = result.resultCode ?? result.Code ?? result.code;
    if (code !== undefined && code !== null && Number(code) !== 200) {
      throw new Error(result.resultMsg || result.Message || result.message || '页面内容加载失败');
    }

    let html = result.data ?? result.Data;
    if (typeof html === 'string') {
      try {
        const parsed = JSON.parse(html);
        if (typeof parsed === 'string') {
          html = parsed;
        }
      } catch (ignore) {}
    }

    if (typeof html !== 'string') {
      throw new Error('getAppHtml 返回的 data 不是字符串');
    }

    const normalized = html.trimStart();
    if (!/^<!doctype\s+html\b/i.test(normalized) ||
        !/<html\b/i.test(normalized) ||
        !/<head\b/i.test(normalized) ||
        !/<body\b/i.test(normalized)) {
      throw new Error('getAppHtml 未返回完整 HTML 文档');
    }

    document.open();
    document.write(html);
    document.close();
  } catch (error) {
    console.error('加载内置页面失败：', error);
    document.body.innerHTML = '';
    const message = document.createElement('pre');
    message.style.cssText = 'padding:16px;color:#d93025;white-space:pre-wrap;';
    message.textContent = '页面加载失败：' + (error && error.message ? error.message : '未知错误');
    document.body.appendChild(message);
  }
})();
