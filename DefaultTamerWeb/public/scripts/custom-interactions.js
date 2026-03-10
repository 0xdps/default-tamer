// Minimal custom interactions for native HTML elements
// Replaces 84KiB tailwindplus-elements.js with ~2KiB custom code

// Dialog interactions (mobile menu, search modal)
document.addEventListener('click', (e) => {
  const dialogTrigger = e.target.closest('[data-dialog-trigger]');
  if (dialogTrigger) {
    const dialogId = dialogTrigger.dataset.dialogTrigger;
    const dialog = document.getElementById(dialogId);
    if (dialog?.tagName === 'DIALOG') {
      dialog.showModal();
    }
  }

  const dialogClose = e.target.closest('[data-dialog-close]');
  if (dialogClose) {
    const dialog = dialogClose.closest('dialog');
    if (dialog) dialog.close();
  }

  // Close dialog when clicking backdrop (fixed inset-0 div inside dialog)
  const backdrop = e.target.closest('dialog > .fixed.inset-0');
  if (backdrop) {
    const dialog = backdrop.closest('dialog');
    if (dialog) dialog.close();
  }

  // Also handle clicking on the dialog element itself (browser default backdrop)
  if (e.target.tagName === 'DIALOG') {
    const rect = e.target.getBoundingClientRect();
    // Check if click was outside the actual dialog content
    if (e.clientX < rect.left || e.clientX > rect.right ||
        e.clientY < rect.top || e.clientY > rect.bottom) {
      e.target.close();
    }
  }
});

// Escape key closes dialog
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    const dialog = document.querySelector('dialog[open]');
    if (dialog) dialog.close();
  }
});

// Dropdown menu keyboard navigation
document.addEventListener('keydown', (e) => {
  const menuTrigger = e.target.closest('[data-menu-trigger]');
  if (!menuTrigger) return;

  const menu = document.getElementById(menuTrigger.getAttribute('aria-controls'));
  if (!menu) return;

  const items = Array.from(menu.querySelectorAll('a[href], button'));
  if (items.length === 0) return;

  switch (e.key) {
    case 'ArrowDown':
    case 'ArrowUp': {
      e.preventDefault();
      const currentIndex = items.indexOf(document.activeElement);
      const nextIndex = e.key === 'ArrowDown' 
        ? (currentIndex + 1) % items.length 
        : (currentIndex - 1 + items.length) % items.length;
      items[nextIndex]?.focus();
      break;
    }
    case 'Home':
      e.preventDefault();
      items[0]?.focus();
      break;
    case 'End':
      e.preventDefault();
      items[items.length - 1]?.focus();
      break;
  }
});

// Copy to clipboard
document.addEventListener('click', (e) => {
  const copyBtn = e.target.closest('[data-copy]');
  if (!copyBtn) return;

  const targetId = copyBtn.dataset.copy;
  const target = document.getElementById(targetId);
  if (!target) return;

  const originalText = copyBtn.textContent;
  navigator.clipboard.writeText(target.textContent || '').then(() => {
    copyBtn.textContent = 'Copied!';
    copyBtn.disabled = true;
    setTimeout(() => {
      copyBtn.textContent = originalText;
      copyBtn.disabled = false;
    }, 2000);
  }).catch((err) => {
    console.error('Failed to copy:', err);
    copyBtn.textContent = 'Failed to copy';
    setTimeout(() => {
      copyBtn.textContent = originalText;
    }, 2000);
  });
});

// Tab group interactions
document.addEventListener('change', (e) => {
  const radio = e.target.closest('input[type="radio"][name][data-tab-panel]');
  if (!radio) return;

  const panelId = radio.dataset.tabPanel;
  const group = radio.closest('[role="tablist"]')?.parentElement;
  if (!group) return;

  // Hide all panels, show selected
  group.querySelectorAll('[role="tabpanel"]').forEach(panel => {
    panel.hidden = panel.id !== panelId;
  });
});

// Details/disclosure styling (smooth animation)
document.addEventListener('toggle', (e) => {
  if (e.target.tagName !== 'DETAILS') return;
  const details = e.target;
  
  if (details.open) {
    details.classList.add('open');
    details.classList.remove('closed');
  } else {
    details.classList.remove('open');
    details.classList.add('closed');
  }
});

// Initialize details elements on load
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('details').forEach(details => {
    if (details.open) {
      details.classList.add('open');
    } else {
      details.classList.add('closed');
    }
  });
});

console.log('[custom-interactions] Loaded');
