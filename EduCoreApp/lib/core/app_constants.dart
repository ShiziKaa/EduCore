class AppConstants {
  static const apiBaseUrl = 'http://127.0.0.1:8000';
  static const dbFolderName = 'EduCore_DB';
  static const searchEngineExeName = 'search_engine.exe';
  static const developerName = 'Akmammedow Akmammet';
  static const developerEmail = 'shizikaa24@gmail.com';
  static const allowedDocumentExtensions = ['docx', 'xlsx'];
  static const allowedImageExtensions = ['jpg', 'jpeg', 'png', 'svg'];
  static const allowedVideoExtensions = ['mp4', 'avi', 'mov', 'mkv'];
  static const allowedUploadExtensions = [
    ...allowedDocumentExtensions,
    ...allowedImageExtensions,
    ...allowedVideoExtensions,
  ];
  static const instituteLogoExtensions = ['png', 'jpg', 'jpeg'];
  static const maxNewsItems = 15;
}
