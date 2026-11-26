"""Verify native inventory of the delivered Dart-business APK, not build staging."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

for argument in sys.argv[1:]:
    path = Path(argument)
    with zipfile.ZipFile(path) as archive:
        native = sorted(name for name in archive.namelist() if name.startswith('lib/'))
        assert native, 'No native APK payload'
        forbidden = ('swift', 'foundation', 'wust', 'libicu', 'libdispatch', 'libblocksruntime')
        assert not any(any(word in Path(name).name.lower() for word in forbidden)
                       for name in native), 'Swift payload still packaged'
        assert all(name.split('/')[1] in {'arm64-v8a', 'x86_64'} for name in native)
        for name in archive.namelist():
            if name.endswith('.dex'):
                assert b'Lcn/edu/wust/foundation/' not in archive.read(name), 'Legacy business bridge in DEX'
        print(json.dumps({'file':path.name,'bytes':path.stat().st_size,
                          'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                          'native':native,'swiftPayload':False}, ensure_ascii=False))
