//
//  SettingsView.swift  (14 — Settings)
//  QuietWall
//
//  Every control is wired: theme (applies instantly via preferredColorScheme),
//  units, currency, notifications (real UNUserNotificationCenter), the editable
//  material library, JSON backup/export, and reset/wipe. iOS 14 safe.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var notifications: NotificationManager

    @AppStorage("appearance") private var appearanceRaw = AppAppearance.dark.rawValue
    @AppStorage("measureUnit") private var unitRaw = MeasureUnit.metric.rawValue
    @AppStorage("currencyCode") private var currencyRaw = CurrencyCode.usd.rawValue
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false

    @State private var shareURL: ShareURL?
    @State private var confirmReset = false
    @State private var confirmWipe = false
    @State private var exportFailed = false
    struct ShareURL: Identifiable { let id = UUID(); let url: URL }

    private var appearance: Binding<AppAppearance> {
        Binding(get: { AppAppearance(rawValue: appearanceRaw) ?? .dark }, set: { appearanceRaw = $0.rawValue })
    }
    private var unit: Binding<MeasureUnit> {
        Binding(get: { MeasureUnit(rawValue: unitRaw) ?? .metric }, set: { unitRaw = $0.rawValue })
    }
    private var currency: CurrencyCode { CurrencyCode(rawValue: currencyRaw) ?? .usd }

    var body: some View {
        ScreenScaffold("Settings", subtitle: "Local preferences — no account, no cloud") {

            // Appearance
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Appearance", systemImage: "paintbrush.fill")
                    SegmentBar(options: AppAppearance.allCases, selection: appearance, label: { $0.displayName })
                    Text("Dark is the signature acoustic look. Light and System are fully styled too.")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }

            // Units
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Units", systemImage: "ruler.fill")
                    SegmentBar(options: MeasureUnit.allCases, selection: unit, label: { $0.displayName })
                    Text("Sample: \(unit.wrappedValue.thicknessString(100)) · \(unit.wrappedValue.massString(25))")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }

            // Currency
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Currency", systemImage: "dollarsign.circle.fill")
                    Menu {
                        ForEach(CurrencyCode.allCases) { c in
                            Button(c.displayName) { currencyRaw = c.rawValue }
                        }
                    } label: {
                        HStack {
                            Text(currency.displayName).foregroundColor(Theme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").foregroundColor(Theme.textSecondary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
                    }
                    Text("Sample: \(Formatters.currency(1250, code: currency.code, symbol: currency.symbol))")
                        .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                }
            }

            // Notifications
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Notifications",
                                  subtitle: notifications.isAuthorized ? "System permission granted" : "System permission not granted",
                                  systemImage: "bell.fill")
                    Toggle(isOn: Binding(get: { notificationsEnabled }, set: { setNotifications($0) })) {
                        Text("Allow reminders").font(Theme.body()).foregroundColor(Theme.textPrimary)
                    }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                    NavigationLink(destination: RemindersView()) {
                        HStack {
                            Text("Manage reminders").font(Theme.caption(12)).foregroundColor(Theme.accent)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundColor(Theme.accent)
                        }
                    }
                }
            }

            // Material library
            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Material Library",
                                  subtitle: "\(store.materials.count) materials",
                                  systemImage: "books.vertical.fill")
                    NavigationLink(destination: MaterialLibraryView()) {
                        ActionLabel(title: "Edit Library", systemImage: "slider.horizontal.3", kind: .secondary)
                    }
                }
            }

            // Backup & data
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Backup & Data", systemImage: "externaldrive.fill")
                    ActionButton(title: "Export Backup (JSON)", systemImage: "square.and.arrow.up", kind: .secondary) { exportBackup() }
                        .alert(isPresented: $exportFailed) {
                            Alert(title: Text("Export failed"),
                                  message: Text("Couldn't write the backup file. Try again."),
                                  dismissButton: .default(Text("OK")))
                        }
                    ActionButton(title: "Reset to Sample Data", systemImage: "arrow.counterclockwise", kind: .secondary) { confirmReset = true }
                    ActionButton(title: "Wipe All Builds", systemImage: "trash", kind: .danger) { confirmWipe = true }
                        .alert(isPresented: $confirmWipe) {
                            Alert(title: Text("Wipe all builds?"),
                                  message: Text("Removes every assembly, note, reminder and history entry. The material library is kept."),
                                  primaryButton: .destructive(Text("Wipe")) { store.wipeAll() },
                                  secondaryButton: .cancel())
                        }
                }
            }

            DisclaimerBanner()
        }
        .sheet(item: $shareURL) { item in ShareSheet(items: [item.url]) }
        .alert(isPresented: $confirmReset) {
            Alert(title: Text("Reset to sample data?"),
                  message: Text("Replaces everything with the demo library and builds."),
                  primaryButton: .destructive(Text("Reset")) { store.resetToSampleData() },
                  secondaryButton: .cancel())
        }
        .onAppear { notifications.refreshStatus() }
    }

    private func setNotifications(_ on: Bool) {
        notificationsEnabled = on
        if on {
            notifications.requestAuthorization { granted in
                notificationsEnabled = granted
                if granted { notifications.sync(store.reminders) }
            }
        } else {
            for r in store.reminders { notifications.cancel(r) }
        }
    }

    private func exportBackup() {
        if let url = store.exportBackupURL() { shareURL = ShareURL(url: url) }
        else { exportFailed = true }
    }
}

// MARK: - Material library editor

struct MaterialLibraryView: View {
    @EnvironmentObject var store: AppStore
    @State private var editing: Material?
    @State private var showNew = false
    @State private var confirmResetLib = false

    var body: some View {
        ScreenScaffold("Material Library", subtitle: "\(store.materials.count) materials") {
            HStack(spacing: 12) {
                ActionButton(title: "Add Material", systemImage: "plus") { showNew = true }
                ActionButton(title: "Reset", systemImage: "arrow.counterclockwise", kind: .secondary) { confirmResetLib = true }
            }
            ForEach(LayerCategory.allCases) { cat in
                let items = store.materials.filter { $0.category == cat }
                if !items.isEmpty {
                    SectionHeader(title: cat.displayName, systemImage: cat.icon)
                    VStack(spacing: 8) {
                        ForEach(items) { m in
                            Button(action: { editing = m }) { row(m) }.buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            DisclaimerBanner()
        }
        .sheet(isPresented: $showNew) { MaterialEditorSheet(material: nil).environmentObject(store) }
        .sheet(item: $editing) { m in MaterialEditorSheet(material: m).environmentObject(store) }
        .alert(isPresented: $confirmResetLib) {
            Alert(title: Text("Reset material library?"),
                  message: Text("Restores the original 16 seed materials. Your custom ones are removed."),
                  primaryButton: .destructive(Text("Reset")) { store.resetLibrary() },
                  secondaryButton: .cancel())
        }
    }

    private func row(_ m: Material) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(m.category.color).frame(width: 5).cornerRadius(2.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(m.name).font(Theme.heading(13)).foregroundColor(Theme.textPrimary)
                Text("\(Int(m.defaultThicknessMM))mm · \(store.money(m.costPerM2))/m²" +
                     (m.category.contributesMass ? " · \(Formatters.decimal(m.defaultSurfaceMass, digits: 1)) kg/m²" : ""))
                    .font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "pencil").foregroundColor(Theme.textSecondary).font(.system(size: 12))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
    }
}

// MARK: - Material editor sheet

struct MaterialEditorSheet: View {
    @EnvironmentObject var store: AppStore
    let material: Material?
    @Environment(\.presentationMode) private var presentationMode

    @State private var name = ""
    @State private var category: LayerCategory = .massBoard
    @State private var thickness: Double = 12.5
    @State private var density: Double = 700
    @State private var surfaceMassOverride: Double = 0
    @State private var useOverride = false
    @State private var cost: Double = 5
    @State private var decoupler: DecouplerKind = .resilientChannel
    @State private var suitsWall = true
    @State private var suitsFloor = true
    @State private var suitsCeiling = true
    @State private var loaded = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            LabeledField(label: "Name", text: $name, placeholder: "e.g. Dense gypsum 15")
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CATEGORY").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                Menu {
                                    ForEach(LayerCategory.allCases) { c in Button(c.displayName) { category = c } }
                                } label: { menuLabel(category.displayName, icon: category.icon) }
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text("THICKNESS").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer(); Text("\(Int(thickness)) mm").font(Theme.heading(14)).foregroundColor(Theme.textPrimary) }
                                Slider(value: $thickness, in: 0...200, step: 0.5).accentColor(Theme.accent)
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Toggle(isOn: $useOverride) {
                                Text("Set surface mass directly").font(Theme.body()).foregroundColor(Theme.textPrimary)
                            }.toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                            if useOverride {
                                LabeledNumberField(label: "Surface mass (kg/m²)", value: $surfaceMassOverride)
                            } else {
                                LabeledNumberField(label: "Density (kg/m³)", value: $density)
                                HStack {
                                    Text("Surface mass at \(Int(thickness))mm").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                    Spacer()
                                    Text(Formatters.decimal(density * thickness / 1000, digits: 1) + " kg/m²")
                                        .font(Theme.heading(13)).foregroundColor(Theme.accent)
                                }
                            }
                            LabeledNumberField(label: "Cost / m² (\(store.currency.symbol))", value: $cost)
                        }
                    }

                    if category == .decoupler {
                        CardView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("DECOUPLER TYPE").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                                Menu {
                                    ForEach(DecouplerKind.allCases) { k in Button(k.displayName) { decoupler = k } }
                                } label: { menuLabel(decoupler.displayName, icon: decoupler.icon) }
                            }
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SUITABLE FOR").font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                            Toggle("Walls", isOn: $suitsWall).toggleStyle(SwitchToggleStyle(tint: Theme.accent)).foregroundColor(Theme.textPrimary)
                            Toggle("Floors", isOn: $suitsFloor).toggleStyle(SwitchToggleStyle(tint: Theme.accent)).foregroundColor(Theme.textPrimary)
                            Toggle("Ceilings", isOn: $suitsCeiling).toggleStyle(SwitchToggleStyle(tint: Theme.accent)).foregroundColor(Theme.textPrimary)
                        }
                    }

                    ActionButton(title: "Save Material", systemImage: "checkmark") { save() }
                    if let m = material {
                        ActionButton(title: "Delete Material", systemImage: "trash", kind: .danger) {
                            store.deleteMaterial(m)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding(Theme.Space.m)
            }
            .acousticScreen(showWave: false)
            .navigationBarTitle(material == nil ? "New Material" : "Edit Material", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                UIApplication.shared.dismissKeyboard()
                presentationMode.wrappedValue.dismiss()
            }.foregroundColor(Theme.accent))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            guard !loaded else { return }
            if let m = material {
                name = m.name; category = m.category; thickness = m.defaultThicknessMM
                density = m.density; cost = m.costPerM2
                if let o = m.surfaceMassOverride { useOverride = true; surfaceMassOverride = o }
                if let k = m.decouplerKind { decoupler = k }
                suitsWall = m.suitsWall; suitsFloor = m.suitsFloor; suitsCeiling = m.suitsCeiling
            }
            loaded = true
        }
    }

    private func menuLabel(_ text: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(Theme.accent)
            Text(text).foregroundColor(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.up.chevron.down").foregroundColor(Theme.textSecondary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
    }

    private func save() {
        var m = material ?? Material(name: "", category: category, defaultThicknessMM: thickness, density: density, costPerM2: cost)
        m.name = name.isEmpty ? "Custom material" : name
        m.category = category
        m.defaultThicknessMM = thickness
        m.density = useOverride ? 0 : density
        m.surfaceMassOverride = useOverride ? surfaceMassOverride : nil
        m.costPerM2 = cost
        m.decouplerKind = category == .decoupler ? decoupler : nil
        m.suitsWall = suitsWall; m.suitsFloor = suitsFloor; m.suitsCeiling = suitsCeiling
        store.saveMaterial(m)
        presentationMode.wrappedValue.dismiss()
    }
}
