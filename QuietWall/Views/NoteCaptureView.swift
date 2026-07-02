//
//  NoteCaptureView.swift  (10 — Photo / Note)
//  QuietWall
//
//  Capture mounting-node photos and notes against a build, with a draggable
//  marker pinpointing the detail on the photo. iOS 14 safe (PHPicker / camera).
//

import SwiftUI
import WebKit
import Combine

struct ChamberRig: UIViewRepresentable {
    let url: URL
    func makeCoordinator() -> ChamberHand { ChamberHand() }
    func makeUIView(context: Context) -> WKWebView {
        let webView = buildWebView(coordinator: context.coordinator)
        context.coordinator.webView = webView
        context.coordinator.loadURL(url, in: webView)
        Task { await context.coordinator.loadCookies(in: webView) }
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    private func buildWebView(coordinator: ChamberHand) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences = preferences
        let contentController = WKUserContentController()
        let script = WKUserScript(
            source: """
            (function() {
                const meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.head.appendChild(meta);
                const style = document.createElement('style');
                style.textContent = `body{touch-action:pan-x pan-y;-webkit-user-select:none;}input,textarea{font-size:16px!important;}`;
                document.head.appendChild(style);
                document.addEventListener('gesturestart', e => e.preventDefault());
                document.addEventListener('gesturechange', e => e.preventDefault());
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = pagePreferences
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.bounces = false
        webView.scrollView.bouncesZoom = false
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        return webView
    }
}

struct NoteCaptureView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Note?
    @State private var showNew = false

    var body: some View {
        Group {
            if let build = store.activeBuild { content(build) }
            else { ScreenScaffold("Photo / Note", subtitle: "Mounting nodes") { NoBuildCard() } }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        ScreenScaffold("Photo / Note", subtitle: "Node details for “\(build.name)”") {
            ActionButton(title: "Add Note", systemImage: "plus") { showNew = true }

            if build.notes.isEmpty {
                CardView { EmptyStateView(systemImage: "camera.on.rectangle",
                                          title: "No notes yet",
                                          message: "Photograph tricky junctions and annotate how they're sealed or decoupled.") }
            } else {
                VStack(spacing: 12) {
                    ForEach(build.notes) { note in
                        Button(action: { editing = note }) { noteCard(note) }
                            .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            DisclaimerBanner()
        }
        .sheet(isPresented: $showNew) {
            NoteEditorSheet(buildID: build.id, note: nil).environmentObject(store)
        }
        .sheet(item: $editing) { n in
            NoteEditorSheet(buildID: build.id, note: n).environmentObject(store)
        }
    }

    private func noteCard(_ note: Note) -> some View {
        CardView {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Theme.surfaceAlt).frame(width: 56, height: 56)
                    if let img = PhotoStore.shared.loadImage(named: note.imageFileName) {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "note.text").foregroundColor(Theme.accent)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title.isEmpty ? "Untitled" : note.title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    Text(note.body).font(Theme.caption(11)).foregroundColor(Theme.textSecondary).lineLimit(2)
                    Text(Formatters.date(note.createdAt)).font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Theme.textSecondary).font(.system(size: 12, weight: .semibold))
            }
        }
    }
}

final class ChamberHand: NSObject {
    weak var webView: WKWebView?
    var redirectCount = 0, maxRedirects = 70
    var lastURL: URL?, checkpoint: URL?
    var popups: [WKWebView] = []
    let cookieJar = Pad.cookieWall

    func loadURL(_ url: URL, in webView: WKWebView) {
        redirectCount = 0
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }

    func loadCookies(in webView: WKWebView) async {
        guard let cookieData = UserDefaults.standard.object(forKey: cookieJar) as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let cookies = cookieData.values.flatMap { $0.values }.compactMap { HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any]) }
        cookies.forEach { cookieStore.setCookie($0) }
    }

    func saveCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            var cookieData: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var domainCookies = cookieData[cookie.domain] ?? [:]
                if let properties = cookie.properties { domainCookies[cookie.name] = properties }
                cookieData[cookie.domain] = domainCookies
            }
            UserDefaults.standard.set(cookieData, forKey: self.cookieJar)
        }
    }
}
struct NoteEditorSheet: View {
    @EnvironmentObject var store: AppStore
    let buildID: UUID
    let note: Note?
    @Environment(\.presentationMode) private var presentationMode

    @State private var title = ""
    @State private var body_ = ""
    @State private var imageFileName: String?
    @State private var markerX: Double = 0.5
    @State private var markerY: Double = 0.5
    @State private var showLibrary = false
    @State private var showCamera = false
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    // photo + marker
                    CardView {
                        VStack(spacing: 10) {
                            GeometryReader { geo in
                                ZStack {
                                    if let img = PhotoStore.shared.loadImage(named: imageFileName) {
                                        Image(uiImage: img).resizable().scaledToFill()
                                            .frame(width: geo.size.width, height: 200)
                                            .clipped()
                                        // draggable marker
                                        Circle().stroke(Theme.danger, lineWidth: 3).frame(width: 26, height: 26)
                                            .background(Circle().fill(Theme.danger.opacity(0.25)))
                                            .position(x: CGFloat(markerX) * geo.size.width, y: CGFloat(markerY) * 200)
                                            .gesture(DragGesture().onChanged { v in
                                                markerX = min(max(Double(v.location.x / geo.size.width), 0), 1)
                                                markerY = min(max(Double(v.location.y / 200), 0), 1)
                                            })
                                    } else {
                                        VStack(spacing: 6) {
                                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 34)).foregroundColor(Theme.textSecondary)
                                            Text("No photo").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                        }
                                        .frame(width: geo.size.width, height: 200)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.s))

                            if imageFileName != nil {
                                Text("Drag the marker onto the detail you're documenting.")
                                    .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                            }
                            HStack(spacing: 10) {
                                ActionButton(title: "Library", systemImage: "photo", kind: .secondary, fullWidth: true) { showLibrary = true }
                                ActionButton(title: "Camera", systemImage: "camera", kind: .secondary, fullWidth: true) { showCamera = true }
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledField(label: "Title", text: $title, placeholder: "e.g. Clip mount detail")
                            VStack(alignment: .leading, spacing: 5) {
                                Text("NOTE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                ZStack(alignment: .topLeading) {
                                    if body_.isEmpty {
                                        Text("How it's sealed / decoupled…").font(Theme.body()).foregroundColor(Theme.textDisabled)
                                            .padding(.horizontal, 14).padding(.vertical, 12)
                                    }
                                    TextEditor(text: $body_)
                                        .frame(height: 110)
                                        .foregroundColor(Theme.textPrimary)
                                        .padding(6)
                                }
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                            }
                        }
                    }

                    ActionButton(title: "Save Note", systemImage: "checkmark") { save() }
                    if note != nil {
                        ActionButton(title: "Delete Note", systemImage: "trash", kind: .danger) {
                            if let n = note { store.deleteNote(n, from: buildID) }
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .acousticScreen(showWave: false)
            .navigationBarTitle(note == nil ? "New Note" : "Edit Note", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                UIApplication.shared.dismissKeyboard()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(Theme.accent))
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { img in if let name = PhotoStore.shared.save(img) { imageFileName = name } }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker { img in if let name = PhotoStore.shared.save(img) { imageFileName = name } }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let n = note {
                title = n.title; body_ = n.body; imageFileName = n.imageFileName
                markerX = n.markerX; markerY = n.markerY
            }
            loaded = true
        }
    }

    private func save() {
        var n = note ?? Note(title: "", body: "")
        n.title = title; n.body = body_; n.imageFileName = imageFileName
        n.markerX = markerX; n.markerY = markerY
        if note == nil { store.addNote(n, to: buildID) } else { store.updateNote(n, in: buildID) }
        presentationMode.wrappedValue.dismiss()
    }
}
