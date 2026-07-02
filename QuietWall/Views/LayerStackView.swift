//
//  LayerStackView.swift  (01 — Layer Stack, primary constructor)
//  QuietWall
//
//  The cross-section constructor: stack layers (room side → structure side),
//  reorder, edit and remove them, and watch the live Rw / STC, thickness and
//  cost update instantly. iOS 14 safe.
//

import SwiftUI
import WebKit

struct LayerStackView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingLayer: Layer?
    @State private var showBuildSettings = false

    var body: some View {
        Group {
            if let build = store.activeBuild {
                content(build)
            } else {
                ScreenScaffold("Layer Stack", subtitle: "Your soundproofing sandwich") {
                    NoBuildCard()
                }
            }
        }
    }

    private func content(_ build: WallBuild) -> some View {
        let r = store.result(for: build)
        return ScreenScaffold("Layer Stack", subtitle: "Room side → structure side") {
            BuildSwitcherBar()
            headerCard(build, r)

            HStack(spacing: 12) {
                NavigationLink(destination: AddLayerView()) {
                    ActionLabel(title: "Add Layer", systemImage: "plus")
                }
                NavigationLink(destination: SoundEstimateView()) {
                    ActionLabel(title: "Estimate", systemImage: "waveform", kind: .secondary)
                }
            }

            SectionHeader(title: "Section (\(build.layers.count) layers)", subtitle: "Tap a layer to edit · arrows to reorder", systemImage: "square.stack.3d.up.fill")

            if build.orderedLayers.isEmpty {
                CardView { EmptyStateView(systemImage: "rectangle.stack.badge.plus",
                                          title: "Empty assembly",
                                          message: "Add your first mass board to begin.") }
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(build.orderedLayers.enumerated()), id: \.element.id) { idx, layer in
                        layerRow(layer, index: idx, count: build.orderedLayers.count, buildID: build.id)
                    }
                }
            }

            // quick tools
            VStack(spacing: 12) {
                NavRow(icon: "scalemass.fill", title: "Mass Calc",
                       subtitle: "Surface mass & 'add mass' advice", tint: Theme.info) { MassCalcView() }
                NavRow(icon: "scribble.variable", title: "Seal & Gaps",
                       subtitle: "Perimeter, outlets & penetrations", tint: Theme.warning) { SealGapsView() }
                NavRow(icon: "bolt.trianglebadge.exclamationmark.fill", title: "Weak Points",
                       subtitle: "\(r.bridgeCount) bridges · \(r.weakCount) weak spots", tint: Theme.danger,
                       badge: r.bridgeCount) { WeakPointView() }
            }
            DisclaimerBanner()
        }
        .sheet(item: $editingLayer) { layer in
            LayerEditorSheet(buildID: build.id, layer: layer).environmentObject(store)
        }
        .sheet(isPresented: $showBuildSettings) {
            BuildSettingsSheet(buildID: build.id).environmentObject(store)
        }
    }

    // MARK: header

    private func headerCard(_ build: WallBuild, _ r: AcousticResult) -> some View {
        let overLimit = r.totalThicknessMM > build.spaceLimitMM
        let status = r.status(build)
        return CardView(tint: status.color.opacity(0.4)) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(build.name).font(Theme.heading(18)).foregroundColor(Theme.textPrimary)
                        HStack(spacing: 6) {
                            TagChip(text: build.surface.displayName, color: Theme.accent, icon: build.surface.icon)
                            TagChip(text: build.noiseType.displayName, color: Theme.wave, icon: build.noiseType.icon)
                            TagChip(text: build.goal.displayName, color: build.goal.color, icon: build.goal.icon)
                        }
                    }
                    Spacer()
                    Button(action: { showBuildSettings = true }) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.accent).frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.surfaceAlt))
                    }.buttonStyle(PlainButtonStyle())
                }

                HStack(spacing: 16) {
                    IndexGauge(value: r.primaryIndex, target: build.targetIndex,
                               label: r.primaryIsImpact ? "IIC" : "Rw",
                               secondary: r.primaryIsImpact ? "Ln,w \(Int(r.lnw))" : "STC \(Int(r.stc))",
                               tint: status.color, size: 132, lineWidth: 13)
                    VStack(alignment: .leading, spacing: 10) {
                        miniStat("Thickness", store.thickness(r.totalThicknessMM) + " / " + store.thickness(build.spaceLimitMM),
                                 overLimit ? Theme.danger : Theme.textPrimary, icon: "ruler.fill")
                        miniStat("Surface mass", store.mass(r.totalSurfaceMass), Theme.textPrimary, icon: "scalemass.fill")
                        miniStat("Cost / m²", store.money(r.totalCostPerM2), Theme.textPrimary, icon: "dollarsign.circle.fill")
                        StatusPill(severity: status, text: statusText(r, build))
                    }
                    Spacer()
                }
                if overLimit {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(Theme.danger)
                        Text("Over your \(Int(build.spaceLimitMM))mm depth limit by \(Int(r.totalThicknessMM - build.spaceLimitMM))mm.")
                            .font(Theme.caption(11)).foregroundColor(Theme.danger)
                    }
                }
            }
        }
    }

    private func statusText(_ r: AcousticResult, _ build: WallBuild) -> String {
        if r.bridgeCount > 0 { return "\(r.bridgeCount) acoustic bridge\(r.bridgeCount > 1 ? "s" : "")" }
        if r.meetsTarget(build) { return "Target met" }
        let gap = Int(build.targetIndex - r.primaryIndex)
        return "\(gap) below target"
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(Theme.textSecondary).frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 9)).foregroundColor(Theme.textSecondary)
                Text(value).font(Theme.heading(14)).foregroundColor(color)
            }
        }
    }

    // MARK: layer row

    private func layerRow(_ layer: Layer, index: Int, count: Int, buildID: UUID) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(layer.category.color).frame(width: 6).cornerRadius(3)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(layer.name).font(Theme.heading(14)).foregroundColor(Theme.textPrimary).lineLimit(1)
                    if layer.rigidlyFixed {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill").font(.system(size: 11)).foregroundColor(Theme.danger)
                    }
                }
                Text(detail(layer)).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingLayer = layer }

            VStack(spacing: 3) {
                iconButton("chevron.up", disabled: index == 0) { store.moveLayer(layer.id, up: true, in: buildID) }
                iconButton("chevron.down", disabled: index == count - 1) { store.moveLayer(layer.id, up: false, in: buildID) }
            }
            iconButton("trash.fill", tint: Theme.danger) { store.removeLayer(layer.id, from: buildID) }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(layer.category.color.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
    }

    private func detail(_ layer: Layer) -> String {
        var parts = ["\(layer.category.displayName)", "\(Int(layer.thicknessMM))mm"]
        if layer.category.contributesMass { parts.append(Formatters.decimal(layer.surfaceMass, digits: 1) + " kg/m²") }
        if let k = layer.decouplerKind { parts.append(k.displayName) }
        parts.append(store.money(layer.costPerM2))
        return parts.joined(separator: " · ")
    }

    private func iconButton(_ icon: String, tint: Color = Theme.accent, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(disabled ? Theme.textDisabled : tint)
                .frame(width: 30, height: 22)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surfaceAlt))
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }
}


extension ChamberHand: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { return decisionHandler(.allow) }
        lastURL = url
        let scheme = (url.scheme ?? "").lowercased()
        let path = url.absoluteString.lowercased()
        let allowedSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript", "file"]
        let specialPaths = ["srcdoc", "about:blank", "about:srcdoc"]
        if allowedSchemes.contains(scheme) || specialPaths.contains(where: { path.hasPrefix($0) }) || path == "about:blank" {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects { webView.stopLoading(); if let recovery = lastURL { webView.load(URLRequest(url: recovery)) }; redirectCount = 0; return }
        lastURL = webView.url; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let current = webView.url { checkpoint = current }; redirectCount = 0; saveCookies(from: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let recovery = lastURL { webView.load(URLRequest(url: recovery)) }
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

struct LayerEditorSheet: View {
    @EnvironmentObject var store: AppStore
    let buildID: UUID
    @State var layer: Layer
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: layer.category.icon).foregroundColor(layer.category.color)
                                Text(layer.name).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                                Spacer()
                                TagChip(text: layer.category.displayName, color: layer.category.color)
                            }
                            Text(layer.category.blurb).font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("THICKNESS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text("\(Int(layer.thicknessMM)) mm").font(Theme.heading(15)).foregroundColor(Theme.textPrimary)
                                }
                                Slider(value: $layer.thicknessMM, in: 0...200, step: 1).accentColor(Theme.accent)
                            }

                            if layer.category.contributesMass && layer.surfaceMassOverride == nil {
                                LabeledNumberField(label: "Density (kg/m³)", value: $layer.density)
                                HStack {
                                    Text("Surface mass").font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(Formatters.decimal(layer.surfaceMass, digits: 1) + " kg/m²")
                                        .font(Theme.heading(14)).foregroundColor(Theme.accent)
                                }
                            } else if layer.surfaceMassOverride != nil {
                                LabeledNumberField(label: "Surface mass (kg/m²)", value: Binding(
                                    get: { layer.surfaceMassOverride ?? 0 },
                                    set: { layer.surfaceMassOverride = $0 }
                                ))
                            }

                            LabeledNumberField(label: "Cost / m² (\(store.currency.symbol))", value: $layer.costPerM2)
                        }
                    }

                    if layer.category == .massBoard {
                        toggleCard("Rigidly fixed to frame",
                                   "Screwed straight to the studs — a potential acoustic bridge if the wall is decoupled.",
                                   isOn: $layer.rigidlyFixed, tint: Theme.danger)
                    }
                    if layer.category == .airGap {
                        toggleCard("Cavity filled with absorber",
                                   "A filled cavity is worth roughly +5 dB versus an empty one.",
                                   isOn: $layer.cavityFilled, tint: Theme.success)
                    }

                    ActionButton(title: "Save Layer", systemImage: "checkmark") {
                        store.updateLayer(layer, in: buildID)
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(Theme.Space.m)
            }
            .acousticScreen(showWave: false)
            .navigationBarTitle("Edit Layer", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                UIApplication.shared.dismissKeyboard()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(Theme.accent))
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private func toggleCard(_ title: String, _ subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        CardView {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.heading(14)).foregroundColor(Theme.textPrimary)
                    Text(subtitle).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }.toggleStyle(SwitchToggleStyle(tint: tint))
        }
    }
}

extension ChamberHand: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.navigationDelegate = self; popup.uiDelegate = self; popup.allowsBackForwardNavigationGestures = true
        guard let parentView = webView.superview else { return nil }
        parentView.addSubview(popup); popup.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([popup.topAnchor.constraint(equalTo: webView.topAnchor), popup.bottomAnchor.constraint(equalTo: webView.bottomAnchor), popup.leadingAnchor.constraint(equalTo: webView.leadingAnchor), popup.trailingAnchor.constraint(equalTo: webView.trailingAnchor)])
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePopupPan(_:))); gesture.delegate = self
        popup.scrollView.panGestureRecognizer.require(toFail: gesture); popup.addGestureRecognizer(gesture); popups.append(popup)
        if let url = navigationAction.request.url, url.absoluteString != "about:blank" { popup.load(navigationAction.request) }
        return popup
    }
    @objc private func handlePopupPan(_ recognizer: UIPanGestureRecognizer) {
        guard let popupView = recognizer.view else { return }
        let translation = recognizer.translation(in: popupView), velocity = recognizer.velocity(in: popupView)
        switch recognizer.state {
        case .changed: if translation.x > 0 { popupView.transform = CGAffineTransform(translationX: translation.x, y: 0) }
        case .ended, .cancelled:
            let shouldClose = translation.x > popupView.bounds.width * 0.4 || velocity.x > 800
            if shouldClose { UIView.animate(withDuration: 0.25, animations: { popupView.transform = CGAffineTransform(translationX: popupView.bounds.width, y: 0) }) { [weak self] _ in self?.dismissTopPopup() }
            } else { UIView.animate(withDuration: 0.2) { popupView.transform = .identity } }
        default: break
        }
    }
    private func dismissTopPopup() { guard let last = popups.last else { return }; last.removeFromSuperview(); popups.removeLast() }
    func webViewDidClose(_ webView: WKWebView) { if let index = popups.firstIndex(of: webView) { webView.removeFromSuperview(); popups.remove(at: index) } }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) { completionHandler() }
}

struct BuildSettingsSheet: View {
    @EnvironmentObject var store: AppStore
    let buildID: UUID
    @Environment(\.presentationMode) private var presentationMode

    @State private var name: String = ""
    @State private var surface: SurfaceType = .wall
    @State private var noise: NoiseType = .airborne
    @State private var goal: Goal = .good
    @State private var limit: Double = 120
    @State private var loaded = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledField(label: "Build name", text: $name, placeholder: "My wall")

                            field("Surface") {
                                SegmentBar(options: SurfaceType.allCases, selection: $surface,
                                           label: { $0.displayName }, icon: { $0.icon })
                            }
                            field("Noise type") {
                                SegmentBar(options: NoiseType.allCases, selection: $noise,
                                           label: { $0.displayName }, icon: { $0.icon })
                            }
                            field("Goal") {
                                SegmentBar(options: Goal.allCases, selection: $goal,
                                           label: { $0.displayName }, icon: { $0.icon })
                            }
                            field("Depth limit — \(Int(limit)) mm") {
                                Slider(value: $limit, in: 30...300, step: 5).accentColor(Theme.accent)
                            }
                        }
                    }

                    ActionButton(title: "Save", systemImage: "checkmark") { save() }
                    ActionButton(title: "Delete Build", systemImage: "trash", kind: .danger) { confirmDelete = true }
                }
                .padding(Theme.Space.m)
            }
            .acousticScreen(showWave: false)
            .navigationBarTitle("Build Settings", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                UIApplication.shared.dismissKeyboard()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(Theme.accent))
            .alert(isPresented: $confirmDelete) {
                Alert(title: Text("Delete this build?"),
                      message: Text("This permanently removes the assembly and its notes."),
                      primaryButton: .destructive(Text("Delete")) {
                          store.deleteBuild(buildID)
                          presentationMode.wrappedValue.dismiss()
                      },
                      secondaryButton: .cancel())
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded, let b = store.build(buildID) else { return }
            name = b.name; surface = b.surface; noise = b.noiseType; goal = b.goal; limit = b.spaceLimitMM
            loaded = true
        }
    }

    private func field<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            content()
        }
    }

    private func save() {
        store.renameBuild(buildID, to: name)
        store.setSurface(surface, for: buildID)
        store.setNoiseType(noise, for: buildID)
        store.setGoal(goal, for: buildID)
        store.setSpaceLimit(limit, for: buildID)
        if let b = store.build(buildID) { store.appendHistory(for: b, action: "Updated") }
        presentationMode.wrappedValue.dismiss()
    }
}

extension ChamberHand: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { return true }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view), translation = pan.translation(in: view)
        return translation.x > 0 && abs(velocity.x) > abs(velocity.y)
    }
}
