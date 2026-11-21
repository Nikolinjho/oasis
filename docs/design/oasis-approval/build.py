from pathlib import Path

ROOT = Path(__file__).resolve().parent
source = (ROOT / 'template.html').read_text()
for marker, name in [('REVIEW_CSS', 'review.css'), ('SCREENS_JS', 'screens.js'), ('PICO_JS', 'pico.js'), ('REVIEW_JS', 'review.js')]:
    value = (ROOT / name).read_text()
    if marker == 'REVIEW_CSS':
        value += '\n' + (ROOT / 'native-layout.css').read_text()
    if marker == 'SCREENS_JS':
        value += '\n' + (ROOT / 'functional-screens.js').read_text()
    if marker == 'REVIEW_JS':
        insertion = (ROOT / 'native-settings.js').read_text() + '\n' + (ROOT / 'native-views.js').read_text()
        value = value.replace('window.oasisReview=', insertion + '\nwindow.oasisReview=')
    source = source.replace('/* ' + marker + ' */', value)
output = ROOT.parent / 'oasis-all-screens-v5.html'
output.write_text(source)
print(output)
