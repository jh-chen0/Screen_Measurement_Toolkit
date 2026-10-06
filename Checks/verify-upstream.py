from pathlib import Path
import hashlib
import json
import re

# Renaming and UI extensions are intentional. Preserve the original ruler,
# drawing, geometry and guide behavior across the feature-directory refactor.
root = Path(__file__).resolve().parent.parent
manifest = json.loads((root / 'Checks/upstream-files.json').read_text())
paths = json.loads((root / 'Checks/upstream-paths.json').read_text())
ui_files = {'main.swift', 'AppDelegate.swift', 'ShapeControlSection.swift', 'ControlContentView.swift',
            'ControlWindow.swift', 'CommandsSection.swift', 'HelpWindow.swift', 'ShapeEditDialog.swift'}
text_files = {'Guides.swift', 'RulerView+Menu.swift', 'ShapeModel.swift'}
verified = 0
for name, fingerprint in manifest['sha256'].items():
    if not name.startswith('Sources/RulerApp/') or Path(name).name in ui_files:
        continue
    current = (root / paths[name]).read_bytes()
    if Path(name).name in text_files:
        current = re.sub(rb'L\(("[^"\n]*")\)', rb'\1', current)
        current = current.replace(b'Screen Measurement Toolkit', b'Distanser')
    assert hashlib.sha256(current).hexdigest() == fingerprint, (name, 'upstream behavior changed')
    verified += 1
assert hashlib.sha256((root / 'LICENSE').read_bytes()).hexdigest() == manifest['sha256']['LICENSE'], 'upstream MIT license must be preserved verbatim'
print(f'PASS {verified} upstream core Swift files preserved after refactor; original MIT license retained verbatim')
