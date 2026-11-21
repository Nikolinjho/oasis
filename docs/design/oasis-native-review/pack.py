from pathlib import Path
import shutil,plistlib
here=Path(__file__).resolve().parent
repo=here.parents[2]
work=Path('/tmp/oasis-native-review')
contents=work/'Review.app/Contents'
(contents/'MacOS').mkdir(parents=True,exist_ok=True)
shutil.copy2(work/'build/debug/Oasis',contents/'MacOS/Review')
shutil.copytree(repo/'app/Resources',contents/'Resources',dirs_exist_ok=True)
(contents/'Resources/Icons').mkdir(exist_ok=True)
claude=Path.home()/'Applications/Oasis.app/Contents/Resources/Icons/claude.png'
assert claude.exists(),'Нужна оригинальная иконка Claude из установленного Oasis'
shutil.copy2(claude,contents/'Resources/Icons/claude.png')
(contents/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':'dev.nikoko.oasis.review','CFBundleExecutable':'Review','CFBundleName':'Oasis Review','LSUIElement':True}))
print(contents/'MacOS/Review')
