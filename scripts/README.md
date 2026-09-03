# Bilim Çeşmesi — build scripts
#
# Paths (do not rename casually — used by Flutter/CMake):
#   EduCoreApp/                 Flutter app
#   EduCoreApp/assets/EduCore_DB   AI bundle source (search_engine.exe + _internal + models)
#   PythonBack/                 FastAPI + PyInstaller sources
#
# Common commands:
#   .\scripts\build_search_engine.ps1     Build/sync search_engine.exe
#   .\scripts\sync_search_engine.ps1      Copy dist → assets + Debug/Release runtime
#   .\scripts\setup_educore_db.ps1        Fresh EduCore_DB (folders, engine, model, chroma)
#   .\scripts\download_model.ps1          Download embedding model + rebuild chroma
#   .\scripts\build_windows.ps1           Engine + Flutter Windows release
#   .\scripts\build_portable.ps1          Same pipeline as build_windows (release package)
#
# Installer (Inno Setup 6+):
#   1) .\scripts\build_windows.ps1
#   2) Compile repo-root EduCore.iss  →  installer\BilimCesmesi_Setup.exe
#
# Shared constants live in scripts\common.ps1
