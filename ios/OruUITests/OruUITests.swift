import XCTest

final class OruUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchWithOnboardingDone() {
        app.launchArguments = ["-hasCompletedOnboarding", "true"]
        app.launch()
    }

    // MARK: - Helpers

    @MainActor
    private func openCreationForm(name: String) {
        app.buttons["plus"].firstMatch.tap()
        let nameField = app.textFields["Añade tu nuevo hábito..."].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "El formulario debe abrirse")
        nameField.tap()
        nameField.typeText(name)
    }

    @MainActor
    private func saveForm() {
        app.scrollViews.firstMatch.tap()
        app.buttons["checkmark"].firstMatch.tap()
    }

    @MainActor
    private func verifyHabitInStats(_ name: String) {
        app.tabBars.buttons["Estadísticas"].tap()
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: 5),
            "El hábito '\(name)' debe aparecer en estadísticas"
        )
    }

    @MainActor
    private func deleteHabit(_ cell: XCUIElement, name: String) {
        cell.swipeLeft()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["Eliminar"].firstMatch.tap()
        XCTAssertFalse(
            app.staticTexts[name].waitForExistence(timeout: 3),
            "El hábito '\(name)' debe desaparecer tras eliminarlo"
        )
    }

    // MARK: - Tests
    
    @MainActor
    func testPI_001_QuantityHabitWithTimerFlow() throws {
        launchWithOnboardingDone()
        // ── Crear hábito con unidad de tiempo ──
        openCreationForm(name: "tiempo")
        app.buttons["Cantidad"].firstMatch.tap()
        app.scrollViews.firstMatch.tap()

        app.staticTexts["uds"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["min"].firstMatch.tap()

        app.textFields["Número/meta"].firstMatch.tap()
        app.textFields["Número/meta"].firstMatch.typeText("30")
        saveForm()

        let habitCell = app.cells.containing(.staticText, identifier: "tiempo").firstMatch
        XCTAssertTrue(habitCell.waitForExistence(timeout: 5), "El hábito debe aparecer tras crearlo")

        // ── Temporizador: selección de hábito ──
        app.tabBars.buttons["Temporizador"].tap()
        XCTAssertTrue(
            app.staticTexts["Registrar tiempo de la sesión:"].waitForExistence(timeout: 5),
            "El temporizador debe cargarse"
        )

        app.switches["0"].firstMatch.tap()
        app.staticTexts["Selecciona uno de tus hábitos"].firstMatch.tap()
        app.buttons["🌟 tiempo"].firstMatch.tap()

        // ── Temporizador: editar tiempo ──
        app.buttons["pencil"].firstMatch.tap()
        app.buttons["minus"].firstMatch.tap()
        app.buttons["checkmark"].firstMatch.tap()

        // ── Temporizador: iniciar y cancelar ──
        app.buttons["play"].firstMatch.tap()
        app.buttons["xmark"].firstMatch.tap()
        app.buttons["Finalizar"].firstMatch.tap()

        // ── Borrar ──
        let inicioTab = app.tabBars.buttons["Inicio"]
        XCTAssertTrue(inicioTab.waitForExistence(timeout: 5), "La tab bar debe reaparecer tras cancelar")
        inicioTab.tap()
        deleteHabit(habitCell, name: "tiempo")
    }

    @MainActor
    func testPI_002_BooleanHabitFullFlow() throws {
        launchWithOnboardingDone()
        // ── Crear ──
        openCreationForm(name: "prueba")
        app.buttons["sab"].firstMatch.tap()
        app.buttons["dom"].firstMatch.tap()
        app.textFields["Deja aquí una nota, estado de ánimo..."].firstMatch.tap()
        app.textFields["Deja aquí una nota, estado de ánimo..."].firstMatch.typeText("esto es una prueba")
        saveForm()

        let habitCell = app.cells.containing(.staticText, identifier: "prueba").firstMatch
        XCTAssertTrue(habitCell.waitForExistence(timeout: 5), "El hábito debe aparecer tras crearlo")

        // ── Editar ──
        habitCell.swipeLeft()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields["Añade tu nuevo hábito..."].firstMatch.waitForExistence(timeout: 3),
            "El formulario de edición debe abrirse"
        )

        let noteFieldInEdit = app.textFields["esto es una prueba"].firstMatch
        noteFieldInEdit.tap()
        noteFieldInEdit.typeText("Actualizado: ")
        saveForm()
        XCTAssertTrue(habitCell.waitForExistence(timeout: 5), "El hábito debe seguir en la lista tras editarlo")

        // Verificar edición reentrando al formulario
        habitCell.swipeLeft()
        app.buttons["pencil"].firstMatch.tap()
        XCTAssertTrue(
            app.textFields["Actualizado: esto es una prueba"].firstMatch.waitForExistence(timeout: 3),
            "La nota debe mostrar el texto actualizado"
        )
        saveForm()
        XCTAssertTrue(habitCell.waitForExistence(timeout: 5))

        // ── Marcar como completado ──
        app.buttons.matching(identifier: "circle").element(boundBy: 0).tap()

        // ── Verificar en estadísticas ──
        verifyHabitInStats("prueba")

        // ── Borrar ──
        app.tabBars.buttons["Inicio"].tap()
        let completedCell = app.cells.containing(.button, identifier: "checkmark.circle.fill").firstMatch
        XCTAssertTrue(completedCell.waitForExistence(timeout: 5))
        deleteHabit(completedCell, name: "prueba")
    }
    
    @MainActor
    func testPI_003_QuantityHabitWithCustomUnit() throws {
        launchWithOnboardingDone()
        // ── Crear con unidad personalizada ──
        openCreationForm(name: "lectura")
        app.buttons["Cantidad"].firstMatch.tap()

        app.staticTexts["uds"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Añadir nueva medida"].firstMatch.tap()

        let unitField = app.textFields["Nueva unidad"].firstMatch
        XCTAssertTrue(unitField.waitForExistence(timeout: 5), "La vista de unidades debe abrirse")
        unitField.tap()
        unitField.typeText("pags")
        app.buttons["plus.circle.fill"].firstMatch.tap()

        app.navigationBars.firstMatch.swipeDown()

        let goalField = app.textFields["Número/meta"].firstMatch
        XCTAssertTrue(goalField.waitForExistence(timeout: 5), "El formulario debe ser visible tras cerrar la gestión de unidades")

        app.staticTexts["uds"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let pagsButton = app.buttons["pags"].firstMatch
        XCTAssertTrue(pagsButton.waitForExistence(timeout: 5), "La unidad 'pags' debe aparecer en el menú")
        pagsButton.tap()

        app.textFields["Número/meta"].firstMatch.tap()
        app.textFields["Número/meta"].firstMatch.typeText("30")
        saveForm()

        let habitCell = app.cells.containing(.staticText, identifier: "lectura").firstMatch
        XCTAssertTrue(habitCell.waitForExistence(timeout: 5), "El hábito debe aparecer tras crearlo")

        // ── Verificar en estadísticas ──
        verifyHabitInStats("lectura")

        // ── Borrar hábito ──
        app.tabBars.buttons["Inicio"].tap()
        deleteHabit(habitCell, name: "lectura")

        // ── Borrar unidad personalizada ──
        app.buttons["plus"].firstMatch.tap()
        app.buttons["Cantidad"].firstMatch.tap()

        app.staticTexts["uds"].firstMatch
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["Añadir nueva medida"].firstMatch.tap()

        let pagsCell = app.staticTexts["pags"].firstMatch
        XCTAssertTrue(pagsCell.waitForExistence(timeout: 3), "La unidad 'pags' debe existir")
        pagsCell.swipeLeft()
        app.buttons["trash"].firstMatch.tap()
        app.buttons["Eliminar"].firstMatch.tap()
    }
    
    @MainActor
    func testPI_004_OnboardingFlow() throws {
        let freshApp = XCUIApplication()
        freshApp.launchArguments = ["-resetOnboarding"]
        freshApp.launch()

        // ── Welcome ──
        XCTAssertTrue(
            freshApp.staticTexts["Da forma a tu mejor versión"].waitForExistence(timeout: 5),
            "La pantalla de bienvenida debe mostrarse"
        )
        freshApp.buttons["Empezar ahora"].firstMatch.tap()

        // ── Registro de nombre ──
        let nameField = freshApp.textFields["Tu nombre"].firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "La pantalla de registro debe mostrarse")
        
        
        nameField.tap()
        nameField.typeText("Test")

        let continueButton = freshApp.buttons["Continuar"].firstMatch
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5), "El botón Continuar debe existir")
        continueButton.tap()

        // ── Home ──
        XCTAssertTrue(
            freshApp.staticTexts["Para hoy"].waitForExistence(timeout: 5),
            "Debe llegar a la pantalla de inicio tras el onboarding"
        )
    }

    @MainActor
    func testPI_005_MainScreensNavigation() throws {
        launchWithOnboardingDone()
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "La tab bar debe ser visible tras el arranque")

        XCTAssertTrue(tabBar.buttons["Inicio"].exists)
        let homeLoaded = app.staticTexts["Para hoy"].waitForExistence(timeout: 5)
        XCTAssertTrue(homeLoaded, "La pantalla Inicio debe cargar su contenido")

        tabBar.buttons["Estadísticas"].tap()
        XCTAssertTrue(
            app.staticTexts["Tu Resumen General"].waitForExistence(timeout: 5),
            "La pantalla Estadísticas debe mostrar su contenido"
        )

        tabBar.buttons["Temporizador"].tap()
        XCTAssertTrue(
            app.staticTexts["Registrar tiempo de la sesión:"].waitForExistence(timeout: 5),
            "La pantalla Temporizador debe mostrar su contenido"
        )
    }
}
