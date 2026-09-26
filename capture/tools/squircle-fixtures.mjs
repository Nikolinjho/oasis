// Эталонные пути squircle с сайта Alcove для тестов порта.
// node capture/tools/squircle-fixtures.mjs > app/Tests/IslandCoreTests/Fixtures/squircle.json
import { copyFileSync, mkdtempSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const here = dirname(fileURLToPath(import.meta.url))
// файл сайта — ES-модуль с расширением .js: копируем как .mjs, чтобы node его импортировал
const module = join(mkdtempSync(join(tmpdir(), 'squircle-')), 'squircle.mjs')
copyFileSync(join(here, '../../site/pretty/squircle-CJT0V4zl.js'), module)
const { a: squirclePath } = await import(module)

// ширина, высота, радиус нижних углов; верхние углы у острова прямые
const cases = [
  [186, 32, 10], [195, 32, 10], [261, 32, 10], [374, 32, 10],
  [283, 51, 14], [190, 73, 18], [203, 90, 18], [370, 175, 28],
]
const out = cases.map(([w, h, r]) => ({
  w, h, r,
  path: squirclePath(w, h, { topLeft: 0, topRight: 0, bottomLeft: r, bottomRight: r }),
}))
console.log(JSON.stringify(out, null, 2))
