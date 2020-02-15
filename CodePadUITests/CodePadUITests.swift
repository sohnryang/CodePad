//
//  CodePadUITests.swift
//  CodePadUITests
//
//  Created by Ryang Sohn on 2020/02/10.
//  Copyright © 2020 Ryang Sohn. All rights reserved.
//

import XCTest

class CodePadUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testDocumentCreation() {
        app.launch()
        
        sleep(2)
        app.buttons["Add"].tap()
        
        sleep(2)
        XCTAssert(app.alerts.element.staticTexts["Create File"].exists)
        
        sleep(2)
        let filenameTextfield = app.alerts.element.textFields.firstMatch
        XCTAssertNotNil(filenameTextfield)
        XCTAssertEqual(filenameTextfield.placeholderValue, "File name")
        filenameTextfield.clearAndTypeText("test.py")
        app.alerts.element.buttons["OK"].tap()
    }

}