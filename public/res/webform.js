const textarea = document.getElementById('content');
const highlight = document.getElementById('content-highlight');
const extInput = document.getElementById('ext');
const fileInputEl = document.getElementById('file');

const updateMirrorContent = () => {
  if (!textarea || !highlight) return;
  const needsTrailingSpace = textarea.value.endsWith("\n");
  highlight.textContent = textarea.value + (needsTrailingSpace ? " " : "");
  if (typeof Prism !== "undefined") {
    Prism.highlightElement(highlight);
  }
};

const syncMirrorScroll = () => {
  if (!textarea || !highlight) return;
  const pre = highlight.parentElement;
  pre.scrollTop = textarea.scrollTop;
  pre.scrollLeft = textarea.scrollLeft;
};

const setMirrorLanguage = () => {
  if (!highlight) return;
  let ext = extInput ? extInput.value.trim() : "";
  if (fileInputEl && fileInputEl.files.length > 0) {
    const filename = fileInputEl.files[0].name;
    const dotIndex = filename.lastIndexOf(".");
    if (dotIndex !== -1) {
      ext = filename.substring(dotIndex + 1);
    }
  }
  let lang = ext;
  if (!ext) lang = "none";
  highlight.className = `language-${lang}`;
  updateMirrorContent();
};

if (textarea && highlight) {
  textarea.addEventListener("input", updateMirrorContent);
  textarea.addEventListener("scroll", syncMirrorScroll);
  if (extInput) {
    extInput.addEventListener("input", setMirrorLanguage);
  }
  if (fileInputEl) {
    fileInputEl.addEventListener("change", setMirrorLanguage);
  }
  setMirrorLanguage();
  updateMirrorContent();
}

document.getElementById('paste-form').onsubmit = async (e) => {
  e.preventDefault();

  const spinner = document.getElementById('paste-spinner');
  const spinnerFrames = ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"];
  let spinnerTimer;
  const startSpinner = () => {
    let frameIndex = 0;
    spinner.textContent = `[${spinnerFrames[frameIndex]}]`;
    spinner.style.display = "inline";
    spinnerTimer = setInterval(() => {
      frameIndex = (frameIndex + 1) % spinnerFrames.length;
      spinner.textContent = `[${spinnerFrames[frameIndex]}]`;
    }, 120);
  };
  const stopSpinner = () => {
    if (spinnerTimer) {
      clearInterval(spinnerTimer);
      spinnerTimer = null;
    }
    spinner.style.display = "none";
  };

  const secret = document.getElementById('secret').checked;
  var ext = document.getElementById('ext').value.trim();
  const fileInput = document.getElementById('file');
  const isFile = fileInput.files.length > 0;

  let body;
  let len = 0;
  let headers = {};

  if (isFile) {
    const file = fileInput.files[0];
    const filename = file.name;
    body = await file.arrayBuffer();
    len = body.byteLength;
    headers['Content-Type'] = 'application/octet-stream';

    const dotIndex = filename.lastIndexOf('.');
    if (dotIndex !== -1) {
      ext = filename.substring(dotIndex + 1).toLowerCase();
    }
  } else {
    body = document.getElementById('content').value;
    len = body.length
    headers['Content-Type'] = 'text/plain';
  }

  if (len > 0) {
    e.target.reset();
    setMirrorLanguage();
    var postUrl = secret ? '/?s=' : '/?';
    postUrl += ext ? `&ext=${ext}` : '';
    const resultWrap = document.getElementById('paste-result');
    const resultDiv = document.getElementById('paste-url');
    const btn = document.getElementById('copy-btn');
    resultDiv.innerHTML = "";
    btn.style.display = "none";
    startSpinner();
    let res;
    try {
      res = await fetch(postUrl, { method: 'POST', headers, body });
      const pasteUrl = await res.text();
      stopSpinner();

      if (!resultWrap.dataset.locked) {
        const width = resultWrap.getBoundingClientRect().width;
        resultWrap.style.width = `${width}px`;
        resultWrap.style.maxWidth = "100%";
        resultWrap.dataset.locked = "1";
      }

      if (res.status == 201) {
        const link = document.createElement('a');
        link.href = pasteUrl;
        link.target = pasteUrl;
        link.textContent = pasteUrl;
        resultDiv.textContent = "Paste URL: ";
        resultDiv.appendChild(link);
        btn.dataset.url = pasteUrl;
        btn.style.display = "inline";
      } else {
        resultDiv.textContent = "Error: " + pasteUrl;
      }
    }
    catch (e) {
      stopSpinner();
      alert(e);
      return;
    }
  } else {
    e.target.reset();
    setMirrorLanguage();
    alert("Empty")
  }
}

document.getElementById('copy-btn').onclick = (e) => {
  const btn = e.target;
  const url = btn.dataset.url;
  if (!url) return;

  navigator.clipboard.writeText(url).then(() => {
    btn.textContent = "Copied!";
    setTimeout(() => btn.textContent = "Copy", 1500);
  }).catch(() => {
    alert("Failed to copy URL");
  });
};
