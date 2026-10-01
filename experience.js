(() => {
  'use strict';
  const zh = document.documentElement.lang.startsWith('zh');
  const t = (en, cn) => zh ? cn : en;
  const create = (tag, cls, text) => { const el = document.createElement(tag); if (cls) el.className = cls; if (text) el.textContent = text; return el; };
  const root = document.documentElement;
  const themeButton = create('button','theme-toggle'); themeButton.type='button';
  const savedTheme = localStorage.getItem('paste-theme');
  if (savedTheme) root.dataset.theme = savedTheme;
  function syncTheme(){ const dark = root.dataset.theme !== 'light'; themeButton.textContent = dark ? '☼' : '☾'; themeButton.title = dark ? t('Switch to light theme','切换浅色主题') : t('Switch to dark theme','切换深色主题'); themeButton.setAttribute('aria-label', themeButton.title); }
  themeButton.addEventListener('click',()=>{ root.dataset.theme = root.dataset.theme === 'light' ? 'dark' : 'light'; localStorage.setItem('paste-theme',root.dataset.theme); syncTheme(); });
  const navActions = document.querySelector('.nav-cta-group'); if(navActions) navActions.prepend(themeButton);
  syncTheme();
  const clips = [
    {type:'text', title:t('A thought worth keeping','留住一个好想法'), content:t('Make room for the work that matters. Paste takes care of the little things.','把注意力留给重要的事，让 Paste 帮你记住细碎的灵感。')},
    {type:'link', title:t('Your next inspiration','下一个灵感来源'), content:'https://github.com/gxlself/Paste'},
    {type:'text', title:t('A favorite snippet','常用代码片段'), content:'let ideas = clipboard.history.filter { $0.isPinned }'}
  ];
  const filters = [['all',t('All','全部')],['text',t('Text','文本')],['link',t('Links','链接')],['pinned',t('Pinned','收藏')]];
  const windowEl = document.querySelector('.demo-window');
  if (windowEl) {
    let filter = 'all', selected = 0;
    const pinned = new Set();
    const search = windowEl.querySelector('input');
    const list = windowEl.querySelector('.demo-clips');
    const preview = windowEl.querySelector('.demo-preview');
    const filterEls = filters.map(([key,label]) => {
      const button = create('button', '', label); button.type = 'button';
      button.addEventListener('click', () => { filter = key; render(); });
      windowEl.querySelector('.demo-filters').append(button); return [key,button];
    });
    function showPreview(index) {
      selected = index;
      const copy = create('button','copy-preview',t('Copy','复制')); copy.type='button'; copy.addEventListener('click',async()=>{ let ok=false; try { if(navigator.clipboard?.writeText){ await navigator.clipboard.writeText(clips[index].content); ok=true; } else { const area=create('textarea'); area.value=clips[index].content; area.style.cssText='position:fixed;opacity:0'; document.body.append(area); area.select(); ok=document.execCommand('copy'); area.remove(); } } catch (_) {} const toast=document.querySelector('.copy-toast'); if(toast){toast.textContent=ok?t('Copied to clipboard','已复制到剪贴板'):t('Copy unavailable','当前环境不支持复制');toast.classList.add('is-visible');setTimeout(()=>toast.classList.remove('is-visible'),1400);} });
      const heading=create('strong','',t('PREVIEW','内容预览')); heading.append(copy); preview.replaceChildren(heading,document.createTextNode(clips[index].content));
      list.querySelectorAll('.clip').forEach(el => el.classList.toggle('selected', Number(el.dataset.index) === selected));
    }
    function render() {
      filterEls.forEach(([key,button]) => button.setAttribute('aria-pressed',String(key === filter)));
      const visible = clips.map((clip,index) => ({...clip,index})).filter(clip => (filter === 'all' || clip.type === filter || (filter === 'pinned' && pinned.has(clip.index))) && `${clip.title} ${clip.content}`.toLowerCase().includes(search.value.trim().toLowerCase()));
      list.replaceChildren();
      visible.forEach(clip => {
        const card = create('article','clip'); card.dataset.index = clip.index;
        const open = create('button','clip-open'); open.type='button';
        open.setAttribute('aria-label',t('Preview: ','预览：') + clip.title);
        open.append(create('span','clip-type',clip.type === 'link' ? '↗ LINK' : 'Aa TEXT'),create('span','clip-title',clip.title),create('span','clip-content',clip.content));
        open.addEventListener('click',() => showPreview(clip.index));
        const pin = create('button','clip-pin',pinned.has(clip.index) ? '★' : '☆'); pin.type='button';
        pin.setAttribute('aria-label',t('Pin: ','收藏：') + clip.title);pin.setAttribute('aria-pressed',String(pinned.has(clip.index)));
        pin.addEventListener('click',() => { pinned.has(clip.index) ? pinned.delete(clip.index) : pinned.add(clip.index); render(); const replacement=list.querySelector(`[data-index="${clip.index}"] .clip-pin`); (replacement || filterEls.find(([key]) => key === filter)[1]).focus(); });
        card.append(open,pin);list.append(card);
      });
      if (!visible.length) { list.append(create('p','empty-clips',t('No clips here. Try another search or filter.','这里还没有内容，试试其他关键词或筛选。'))); preview.textContent=t('Your selected clip will appear here.','选中的内容会显示在这里。'); }
      else showPreview(visible.some(c => c.index === selected) ? selected : visible[0].index);
    }
    search.addEventListener('input',render);
    windowEl.addEventListener('keydown',e=>{ if(e.key==='/' && document.activeElement!==search){e.preventDefault();search.focus();} if(e.key==='Escape' && document.activeElement===search){search.value='';render();search.blur();} });
    windowEl.querySelector('.demo-reset').addEventListener('click',() => {filter='all'; selected=0; pinned.clear();search.value='';render();});
    render();
  }
  const gallery = document.querySelector('.screenshots-grid');
  if (gallery) {
    const bar=create('div','gallery-filters');bar.setAttribute('role','group');bar.setAttribute('aria-label',t('Screenshot platform','截图平台'));
    const groups=[...gallery.querySelectorAll('.screenshot-group')];
    const buttons = ['All','macOS','iOS'].map((name,index) => {
      const button=create('button','',index ? name : t('All devices','全部设备'));button.setAttribute('aria-pressed',String(index === 0));
      button.addEventListener('click',() => { buttons.forEach(b => b.setAttribute('aria-pressed',String(b === button)));groups.forEach((group,i) => {group.hidden=index > 0 && i !== index-1;}); });bar.append(button);return button;
    });gallery.before(bar);
  }
  const images=[...document.querySelectorAll('.screenshot-fig img')];
  if (images.length) {
    const dialog=create('dialog','gallery-dialog');dialog.setAttribute('aria-label',t('Screenshot preview','截图预览'));
    const bar=create('div','dialog-bar'),title=create('span'),controls=create('div','dialog-controls');
    const previous=create('button','', '←'), next=create('button','','→'), close=create('button','',t('Close ×','关闭 ×'));
    previous.setAttribute('aria-label',t('Previous screenshot','上一张截图'));next.setAttribute('aria-label',t('Next screenshot','下一张截图'));
    controls.append(previous,next,close);bar.append(title,controls);const photo=create('img'),caption=create('p','gallery-caption');dialog.append(bar,photo,caption);document.body.append(dialog);
    let active=0;
    function show(index) {active=(index+images.length)%images.length;photo.src=images[active].src;photo.alt=images[active].alt;title.textContent=`${active+1} / ${images.length}`;caption.textContent=images[active].closest('figure').querySelector('figcaption')?.textContent || photo.alt;}
    images.forEach((img,index) => {img.tabIndex=0;img.setAttribute('role','button');img.setAttribute('aria-label',t('Enlarge: ','放大：')+img.alt);function open(){show(index);dialog.showModal();document.body.style.overflow='hidden';}img.addEventListener('click',open);img.addEventListener('keydown',e => {if(e.key === 'Enter' || e.key === ' '){e.preventDefault();open();}});});
    previous.addEventListener('click',()=>show(active-1));next.addEventListener('click',()=>show(active+1));close.addEventListener('click',()=>dialog.close());
    dialog.addEventListener('click',e=>{if(e.target === dialog){const r=dialog.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)dialog.close();}});
    dialog.addEventListener('keydown',e=>{if(e.key==='ArrowLeft')show(active-1);if(e.key==='ArrowRight')show(active+1);});dialog.addEventListener('close',()=>{document.body.style.overflow='';images[active].focus();});
  }
  const copyToast=create('div','copy-toast'); copyToast.setAttribute('role','status'); document.body.append(copyToast);
  const progress=create('div','progress-line');progress.setAttribute('aria-hidden','true');const top=create('button','back-top','↑');top.setAttribute('aria-label',t('Back to top','返回顶部'));top.hidden=true;document.body.append(progress,top);top.addEventListener('click',()=>window.scrollTo({top:0}));
  let queued=false;
  function update(){const max=document.documentElement.scrollHeight-innerHeight;progress.style.transform=`scaleX(${max>0?scrollY/max:0})`;top.hidden=scrollY<600;queued=false;}
  addEventListener('scroll',()=>{if(!queued){queued=true;requestAnimationFrame(update);}},{passive:true});addEventListener('resize',update);update();
})();
