import Foundation

/// A well-known target shown in the GUI and included in `export`.
public struct CuratedTarget: Sendable, Hashable {
  public enum Category: String, Sendable, Hashable, CaseIterable {
    case text
    case web
    case developer
    case documents
    case images
    case audio
    case video
    case archives
    case urlSchemes
    /// Found by scanning installed apps' declared types (see `Discovery`).
    case discovered
  }

  public var target: Target
  public var label: String
  public var category: Category

  public init(_ target: Target, _ label: String, _ category: Category) {
    self.target = target
    self.label = label
    self.category = category
  }
}

/// The curated list of common types, extensions and URL schemes.
///
/// macOS has no single API that enumerates "every" file type, so the GUI
/// seeds its table from this list and augments it by scanning installed
/// apps' declared document types and URL schemes (see `Discovery`).
public enum Curated {
  public static let targets: [CuratedTarget] = [
    // Text
    CuratedTarget(.uti("public.plain-text"), "Plain text", .text),
    CuratedTarget(.ext("txt"), "Text file (.txt)", .text),
    CuratedTarget(.ext("md"), "Markdown (.md)", .text),
    CuratedTarget(.ext("rtf"), "Rich text (.rtf)", .text),
    CuratedTarget(.ext("log"), "Log file (.log)", .text),
    CuratedTarget(.ext("csv"), "CSV (.csv)", .text),

    // Web
    CuratedTarget(.uti("public.html"), "HTML document", .web),
    CuratedTarget(.ext("css"), "CSS (.css)", .web),
    CuratedTarget(.ext("js"), "JavaScript (.js)", .web),
    CuratedTarget(.ext("svg"), "SVG image (.svg)", .web),

    // Developer
    CuratedTarget(.uti("public.source-code"), "Source code", .developer),
    CuratedTarget(.ext("json"), "JSON (.json)", .developer),
    CuratedTarget(.ext("xml"), "XML (.xml)", .developer),
    CuratedTarget(.ext("yaml"), "YAML (.yaml)", .developer),
    CuratedTarget(.ext("yml"), "YAML (.yml)", .developer),
    CuratedTarget(.ext("toml"), "TOML (.toml)", .developer),
    CuratedTarget(.ext("sh"), "Shell script (.sh)", .developer),
    CuratedTarget(.ext("py"), "Python (.py)", .developer),
    CuratedTarget(.ext("rb"), "Ruby (.rb)", .developer),
    CuratedTarget(.ext("go"), "Go (.go)", .developer),
    CuratedTarget(.ext("rs"), "Rust (.rs)", .developer),
    CuratedTarget(.ext("swift"), "Swift (.swift)", .developer),
    CuratedTarget(.ext("c"), "C source (.c)", .developer),
    CuratedTarget(.ext("cpp"), "C++ source (.cpp)", .developer),
    CuratedTarget(.ext("h"), "C header (.h)", .developer),
    CuratedTarget(.ext("java"), "Java (.java)", .developer),
    CuratedTarget(.ext("ts"), "TypeScript (.ts)", .developer),
    CuratedTarget(.ext("sql"), "SQL (.sql)", .developer),
    CuratedTarget(.ext("plist"), "Property list (.plist)", .developer),

    // Documents
    CuratedTarget(.uti("com.adobe.pdf"), "PDF document", .documents),
    CuratedTarget(.ext("doc"), "Word 97 document (.doc)", .documents),
    CuratedTarget(.ext("docx"), "Word document (.docx)", .documents),
    CuratedTarget(.ext("xls"), "Excel 97 workbook (.xls)", .documents),
    CuratedTarget(.ext("xlsx"), "Excel workbook (.xlsx)", .documents),
    CuratedTarget(.ext("ppt"), "PowerPoint 97 (.ppt)", .documents),
    CuratedTarget(.ext("pptx"), "PowerPoint (.pptx)", .documents),
    CuratedTarget(.ext("epub"), "EPUB book (.epub)", .documents),

    // Images
    CuratedTarget(.uti("public.png"), "PNG image", .images),
    CuratedTarget(.uti("public.jpeg"), "JPEG image", .images),
    CuratedTarget(.ext("gif"), "GIF image (.gif)", .images),
    CuratedTarget(.ext("webp"), "WebP image (.webp)", .images),
    CuratedTarget(.ext("heic"), "HEIC image (.heic)", .images),
    CuratedTarget(.ext("tiff"), "TIFF image (.tiff)", .images),

    // Audio
    CuratedTarget(.ext("mp3"), "MP3 audio (.mp3)", .audio),
    CuratedTarget(.ext("aac"), "AAC audio (.aac)", .audio),
    CuratedTarget(.ext("flac"), "FLAC audio (.flac)", .audio),
    CuratedTarget(.ext("wav"), "WAV audio (.wav)", .audio),
    CuratedTarget(.ext("ogg"), "Ogg audio (.ogg)", .audio),

    // Video
    CuratedTarget(.ext("mp4"), "MPEG-4 video (.mp4)", .video),
    CuratedTarget(.ext("mov"), "QuickTime video (.mov)", .video),
    CuratedTarget(.ext("mkv"), "Matroska video (.mkv)", .video),
    CuratedTarget(.ext("avi"), "AVI video (.avi)", .video),
    CuratedTarget(.ext("webm"), "WebM video (.webm)", .video),

    // Archives
    CuratedTarget(.uti("public.zip-archive"), "ZIP archive", .archives),
    CuratedTarget(.ext("tar"), "Tar archive (.tar)", .archives),
    CuratedTarget(.ext("gz"), "Gzip archive (.gz)", .archives),
    CuratedTarget(.ext("7z"), "7-Zip archive (.7z)", .archives),
    CuratedTarget(.ext("rar"), "RAR archive (.rar)", .archives),

    // URL schemes
    CuratedTarget(.urlScheme("http"), "Web links (http)", .urlSchemes),
    CuratedTarget(.urlScheme("https"), "Web links (https)", .urlSchemes),
    CuratedTarget(.urlScheme("mailto"), "Email links (mailto)", .urlSchemes),
    CuratedTarget(.urlScheme("webcal"), "Calendar links (webcal)", .urlSchemes),
    CuratedTarget(.urlScheme("ftp"), "FTP links (ftp)", .urlSchemes),
    CuratedTarget(.urlScheme("ssh"), "SSH links (ssh)", .urlSchemes),
  ]
}
