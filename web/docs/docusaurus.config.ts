import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import prismTheme from './src/prismTheme';

// crocapp.dev is the landing page. GitHub Pages serves one site per repo, so
// the docs live under /docs/ of that same artifact and both surfaces are
// published together by scripts/assemble-site.sh.
const config: Config = {
  title: 'CrocApp',
  tagline: 'Send files with a code phrase',
  // The favicon set, OG image and manifest live in web/landing/ and are served
  // from the site root, so the docs ship no copies. `favicon` and the OG image
  // need absolute URLs: a site-relative path there is prefixed with baseUrl
  // (/docs/). headTags are emitted verbatim, so root-relative paths work.
  favicon: 'https://crocapp.dev/assets/img/favicon/favicon.ico',

  // `v4` includes `fasterByDefault`, which turns on every `future.faster` flag
  // and needs @docusaurus/faster: Rspack, SWC, Lightning CSS, eager git reads.
  future: {
    v4: true,
  },

  // The theme-color values are the two literals web may write (design/implementation.md):
  // browser chrome cannot take a custom property. They are --bg-base light and dark.
  headTags: [
    {
      tagName: 'meta',
      attributes: {
        name: 'theme-color',
        content: '#FFFFFF',
        media: '(prefers-color-scheme: light)',
      },
    },
    {
      tagName: 'meta',
      attributes: {
        name: 'theme-color',
        content: '#000000',
        media: '(prefers-color-scheme: dark)',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'icon',
        type: 'image/png',
        sizes: '96x96',
        href: '/assets/img/favicon/favicon-96x96.png',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'apple-touch-icon',
        href: '/assets/img/favicon/apple-touch-icon.png',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'manifest',
        href: '/assets/img/favicon/site.webmanifest',
      },
    },
  ],

  url: 'https://crocapp.dev',
  baseUrl: '/docs/',
  trailingSlash: true,

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  markdown: {
    // `.md` is CommonMark, `.mdx` is MDX. The default ('mdx' for both) makes a
    // bare `{` open a JavaScript expression, which breaks `## Heading {#id}`
    // and turns any brace a translator types into a build failure. No page here
    // uses JSX, so nothing is given up.
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'throw',
      onBrokenMarkdownImages: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
    localeConfigs: {
      en: {label: 'English', htmlLang: 'en'},
    },
  },

  plugins: [
    [
      '@docusaurus/plugin-client-redirects',
      {
        redirects: [
          {from: '/guide/stored-transfers', to: '/guide/send-as-link'},
          {
            from: ['/guide/power-options', '/guide/settings-and-trust'],
            to: '/guide/settings',
          },
          {from: '/guide/advanced-settings', to: '/guide/settings#advanced'},
          {
            from: '/verify-downloads',
            to: '/getting-started/verify-downloads',
          },
          {from: '/reference/feature-matrix', to: '/reference/croc-cli-interop'},
          {from: '/reference/glossary', to: '/faq#glossary'},
          {from: '/category/getting-started', to: '/getting-started/install'},
          {from: '/category/guide', to: '/guide/sending'},
          {from: '/category/reference', to: '/reference/croc-cli-interop'},
        ],
      },
    ],
  ],

  presets: [
    [
      'classic',
      {
        docs: {
          // `content/`, not `docs/`: the repo already has a docs/ directory and
          // it means something else (contributor and architecture material).
          path: 'content',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/bakirgdev/CrocApp/tree/main/web/docs/',
          showLastUpdateTime: true,
        },
        sitemap: {
          lastmod: 'date',
          ignorePatterns: ['/docs/category/**'],
        },
        // No blog. Release notes belong in GitHub Releases and CHANGELOG.md.
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'https://crocapp.dev/assets/img/og.jpg',
    colorMode: {
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'CrocApp',
      logo: {
        alt: '',
        src: 'img/mascot.webp',
        width: 32,
        height: 32,
      },
      items: [
        {
          href: 'https://crocapp.dev/',
          label: 'crocapp.dev',
          position: 'left',
          target: '_self',
        },
        {
          href: 'https://github.com/bakirgdev/CrocApp',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    // No `style: 'dark'`: it pins Infima's own slate footer palette locally and
    // beats the token mappings in src/css/custom.css.
    footer: {
      links: [
        {
          title: 'Docs',
          items: [
            {label: 'Install', to: '/getting-started/install'},
            {label: 'First Transfer', to: '/getting-started/first-transfer'},
            {label: 'Security and Privacy', to: '/security-and-privacy'},
            {label: 'Troubleshooting', to: '/troubleshooting'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'crocapp.dev', href: 'https://crocapp.dev/'},
            {label: 'GitHub', href: 'https://github.com/bakirgdev/CrocApp'},
            {
              label: 'Release notes',
              href: 'https://github.com/bakirgdev/CrocApp/releases',
            },
            {
              label: 'Issues',
              href: 'https://github.com/bakirgdev/CrocApp/issues',
            },
            {
              label: 'Discussions',
              href: 'https://github.com/bakirgdev/CrocApp/discussions',
            },
          ],
        },
        {
          title: 'More',
          items: [
            {label: 'Privacy', href: 'https://crocapp.dev/privacy/'},
            {label: 'Support', href: 'https://crocapp.dev/support/'},
            {
              label: 'Contributing',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/CONTRIBUTING.md',
            },
            {
              label: 'Security Policy',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/SECURITY.md',
            },
            {
              label: 'croc',
              href: 'https://github.com/schollz/croc',
            },
            {
              label: 'License',
              href: 'https://github.com/bakirgdev/CrocApp/blob/main/LICENSE',
            },
          ],
        },
      ],
      copyright:
        'Built on croc by Zack Scholl (MIT). CrocApp is unofficial and not affiliated with croc.',
    },
    prism: {
      theme: prismTheme,
      darkTheme: prismTheme,
      additionalLanguages: ['bash', 'json', 'swift', 'go'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
