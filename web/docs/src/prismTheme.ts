import type {PrismTheme} from 'prism-react-renderer';

// Every value is a CSS custom property from design/tokens.css. prism-react-renderer
// writes these as inline styles, and the tokens are light-dark() pairs, so one
// object serves both color modes. design/web.md → Docs site.
const prismTheme: PrismTheme = {
  plain: {
    color: 'var(--color-text-primary)',
    backgroundColor: 'var(--color-surface-card)',
  },
  styles: [
    {
      types: ['comment', 'prolog', 'doctype', 'cdata'],
      style: {color: 'var(--color-text-secondary)'},
    },
    {
      types: ['punctuation', 'operator'],
      style: {color: 'var(--color-text-secondary)'},
    },
    {
      types: ['keyword', 'atrule', 'selector', 'tag', 'builtin'],
      style: {color: 'var(--color-accent-text)', fontWeight: '600'},
    },
    {
      types: ['string', 'char', 'attr-value', 'template-string', 'url'],
      style: {color: 'var(--color-accent-text-on-tint)'},
    },
  ],
};

export default prismTheme;
