import SwiftUI

struct UnitManagementView: View {

    var viewModel: HabitViewModel

    @State private var units: [UnitDTO] = []
    @State private var newUnitName = ""
    @State private var unitToRename: UnitDTO?
    @State private var renameName = ""
    @State private var unitToDelete: UnitDTO?
    @State private var showDeleteDialog = false
    @State private var errorMessage: String?
    @State private var showConnectionError = false
    @FocusState private var isAddFieldFocused: Bool

    private var baseUnits: [UnitDTO] { units.filter { $0.isBase } }
    private var customUnits: [UnitDTO] { units.filter { !$0.isBase } }
    private var canAddMore: Bool { customUnits.count < UnitDTO.maxCustomCount }

    private var trimmedNewName: String {
        newUnitName.trimmingCharacters(in: .whitespaces)
    }

    private var isNewNameValid: Bool {
        !trimmedNewName.isEmpty
            && !units.contains(where: { $0.name.lowercased() == trimmedNewName.lowercased() })
    }

    private var isRenameValid: Bool {
        let trimmed = renameName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let lowered = trimmed.lowercased()
        guard lowered != unitToRename?.name.lowercased() else { return false }
        return !units.contains(where: { $0.name.lowercased() == lowered })
    }

    var body: some View {
        NavigationStack {
            List {
                    Section("Esenciales") {
                        ForEach(baseUnits) { unit in
                            Text(unit.name)
                                .oruTextPrimary()
                        }
                    }

                    Section {
                        ForEach(customUnits) { unit in
                            Text(unit.name)
                                .oruTextPrimary()
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        requestDelete(unit)
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                    .tint(.red)

                                    Button {
                                        renameName = unit.name
                                        unitToRename = unit
                                    } label: {
                                        Label("Renombrar", systemImage: "pencil")
                                    }
                                    .tint(.oruPrimary)
                                }
                                .labelStyle(.iconOnly)
                        }

                        if canAddMore {
                            addUnitRow
                        }
                    } header: {
                        Text("Creadas por ti")
                    } footer: {
                        Text("\(customUnits.count)/\(UnitDTO.maxCustomCount) unidades a medida")
                    }
                }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("A tu medida")
                        .oruAccent()
                }
            }
            .alert("Renombrar unidad", isPresented: showRenameBinding) {
                TextField("Nombre", text: $renameName)
                    .onChange(of: renameName) { _, newValue in
                        renameName = String(newValue.prefix(UnitDTO.maxNameLength))
                    }
                Button("Cancelar", role: .cancel) { unitToRename = nil }
                Button("Guardar") { rename() }
                    .disabled(!isRenameValid)
            }
            .alert("¿Eliminar unidad?", isPresented: $showDeleteDialog) {
                Button("Cancelar", role: .cancel) { unitToDelete = nil }
                Button("Eliminar", role: .destructive) { delete() }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("Aceptar", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
            .connectionErrorAlert(
                isPresented: $showConnectionError,
                onRetry: { Task { await loadUnits() } }
            )
            .task { await loadUnits() }
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Fila de nueva unidad

    private var addUnitRow: some View {
        HStack(spacing: 8) {
            TextField("Nueva unidad", text: $newUnitName)
                .oruInputSmall()
                .focused($isAddFieldFocused)
                .onSubmit { addUnit() }
                .onChange(of: newUnitName) { _, newValue in
                    newUnitName = String(newValue.prefix(UnitDTO.maxNameLength))
                }

            Button {
                addUnit()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isNewNameValid ? Color.oruPrimary : .secondary.opacity(0.3))
            }
            .disabled(!isNewNameValid)
        }
    }

    // MARK: - Bindings

    private var showRenameBinding: Binding<Bool> {
        Binding(
            get: { unitToRename != nil },
            set: { if !$0 { unitToRename = nil } }
        )
    }

    // MARK: - Acciones

    private func loadUnits() async {
        let result = await viewModel.loadManagedUnits()
        units = result.units
        if result.connectionError { showConnectionError = true }
    }

    private func addUnit() {
        let name = trimmedNewName
        Task {
            await handle(viewModel.createUnit(name: name)) { newUnitName = "" }
        }
    }

    private func requestDelete(_ unit: UnitDTO) {
        unitToDelete = unit
        showDeleteDialog = true
    }

    private func rename() {
        guard let unit = unitToRename else { return }
        let newName = renameName.trimmingCharacters(in: .whitespaces)
        unitToRename = nil
        Task {
            await handle(viewModel.updateUnit(id: unit.id, name: newName))
        }
    }

    private func delete() {
        guard let unit = unitToDelete else { return }
        unitToDelete = nil
        Task {
            await handle(viewModel.deleteUnit(id: unit.id, name: unit.name))
        }
    }

    /// Gestiona el resultado de una acción de unidad con estado local
    private func handle(
        _ outcome: HabitViewModel.UnitActionOutcome,
        onSuccess: () -> Void = {}
    ) async {
        switch outcome {
        case .success:
            onSuccess()
            await loadUnits() // por ahora get tras operacion porque la lista es pequeña
        case .connectionError:
            showConnectionError = true
        case .failure(let message):
            errorMessage = message
        }
    }
}
