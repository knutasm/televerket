import { defineConfig } from 'vitepress'

export default defineConfig({
  base: '/televerket/',
  lang: 'nb-NO',
  head: [
    ['style', {}, '.VPHero .image-src { max-width: 180px; max-height: 180px; }'],
  ],
  title: 'Televerket dbt-kurs',
  description: 'Kursmateriale for dbt-kurs basert på det fiktive telekomselskapet Televerket',

  markdown: {
    config: (md) => {
      // Escape {{ }} in plain text tokens so Vue doesn't treat them as template
      // expressions. Fenced code blocks get v-pre from VitePress, but inline
      // code spans do not — override the code_inline renderer to escape them.
      md.core.ruler.push('escape_vue_interpolation', (state) => {
        for (const token of state.tokens) {
          if (token.type === 'inline' && token.children) {
            for (const child of token.children) {
              if (child.type === 'text' || child.type === 'html_inline') {
                child.content = child.content
                  .replace(/\{\{/g, '&#123;&#123;')
                  .replace(/\}\}/g, '&#125;&#125;')
              }
            }
          }
        }
      })

      // Override code_inline renderer: HTML-escape content ourselves and
      // additionally escape {{ }} so Vue's template compiler ignores them.
      md.renderer.rules.code_inline = (tokens, idx, _options, _env, self) => {
        const token = tokens[idx]
        const escaped = md.utils.escapeHtml(token.content)
          .replace(/\{\{/g, '&#123;&#123;')
          .replace(/\}\}/g, '&#125;&#125;')
        return `<code${self.renderAttrs(token)}>${escaped}</code>`
      }
    },
  },

  themeConfig: {
    logo: '/televerket.webp',

    nav: [
      { text: 'Hjem', link: '/' },
      {
        text: 'Sesjon 1',
        link: '/sesjon-1/',
      },
      {
        text: 'Sesjon 2',
        items: [
          { text: 'Slides', link: '/sesjon-2/' },
          { text: 'Oppgaver', link: '/sesjon-2/oppgaver' },
        ],
      },
      {
        text: 'Sesjon 3',
        items: [
          { text: 'Slides', link: '/sesjon-3/' },
          { text: 'Oppgaver', link: '/sesjon-3/oppgaver' },
        ],
      },
      { text: 'Makroer', link: '/makroer/' },
      { text: 'Cheat sheet', link: '/cheatsheet' },
    ],

    sidebar: [
      {
        text: 'Sesjon 1',
        link: '/sesjon-1/',
        items: [
          { text: 'Motivasjon', link: '/sesjon-1/motivasjon' },
          { text: 'Hva er dbt', link: '/sesjon-1/dbt' },
          { text: 'Første modell', link: '/sesjon-1/forste-modell' },
        ],
      },
      {
        text: 'Sesjon 2 — Sources og staging',
        link: '/sesjon-2/',
        items: [
          { text: 'Sources og seeds', link: '/sesjon-2/sources-og-seeds' },
          { text: 'Staging og materialisering', link: '/sesjon-2/staging' },
          { text: 'Intermediate-modeller', link: '/sesjon-2/intermediate' },
          { text: 'Testing', link: '/sesjon-2/testing' },
          { text: 'Oppgaver', link: '/sesjon-2/oppgaver' },
        ],
      },
      {
        text: 'Sesjon 3 — Jinja, makroer og pakker',
        link: '/sesjon-3/',
        items: [
          { text: 'Jinja og templating', link: '/sesjon-3/jinja' },
          { text: 'Makroer', link: '/sesjon-3/makroer' },
          { text: 'dbt-pakke-økosystemet', link: '/sesjon-3/pakker' },
          { text: 'Oppgaver', link: '/sesjon-3/oppgaver' },
        ],
      },
      {
        text: 'Makroer',
        items: [
          { text: 'Eksempler og øvelser', link: '/makroer/' },
        ],
      },
    ],

    socialLinks: [],

    search: {
      provider: 'local',
    },

    outline: {
      label: 'På denne siden',
      level: [2, 3],
    },

    docFooter: {
      prev: 'Forrige',
      next: 'Neste',
    },
  },
})
