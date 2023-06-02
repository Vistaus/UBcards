/*****************************************************************************
 * Copyright: 2013 Michael Zanetti <michael_zanetti@gmx.net>      
 * Copyright (C) 2023 Jan Belohoubek, it@sforetelem.cz
 *                                                                           *
 * This file is part of ubsync, fork of tagger                                               *
 *                                                                           *
 * This prject is free software: you can redistribute it and/or modify       *
 * it under the terms of the GNU General Public License as published by      *
 * the Free Software Foundation, either version 3 of the License, or         *
 * (at your option) any later version.                                       *
 *                                                                           *
 * This project is distributed in the hope that it will be useful,           *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of            *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             *
 * GNU General Public License for more details.                              *
 *                                                                           *
 * You should have received a copy of the GNU General Public License         *
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.     *
 *                                                                           *
 ****************************************************************************/

import QtQuick 2.4
import QtQuick.Layouts 1.1
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3
import Lomiri.Components.Popups 1.3
import QtMultimedia 5.0
import QtQuick.Window 2.0
import Lomiri.Content 1.3
import UBcards 0.1

import "encoder.js" as Encoder

MainView {
    id: mainView

    applicationName: "ubcards.belohoub"

    Component.onCompleted: i18n.domain = "ubcards"
    
    property var m_issuer: "undefined"
    property var m_name: "undefined"

    width: units.gu(40)
    height: units.gu(68)

    PageStack {
        id: pageStack
        Component.onCompleted: {
            pageStack.push(cardWalletComponent)
        }
    }

    Connections {
        target: qrCodeReader

        onScanningChanged: {
            if (!qrCodeReader.scanning) {
                mainView.decodingImage = false;
            }
        }

        onValidChanged: {
            if (qrCodeReader.valid) {
                pageStack.pop();
                pageStack.push(editPageComponent, {type: qrCodeReader.type, text: qrCodeReader.text, name: qrCodeReader.name, issuer: qrCodeReader.issuer, imageSource: qrCodeReader.imageSource});
            }
        }
    }

    Connections {
        target: ContentHub
        onExportRequested: {
            // show content picker
            print("******* transfer requested!");
            pageStack.pop();
            pageStack.push(showQRCodeComponent, {transfer: transfer})
        }
        onImportRequested: {
            print("**** import Requested")
            var filePath = String(transfer.items[0].url).replace('file://', '')
            qrCodeReader.processImage(filePath, m_name, m_issuer);
        }

        onShareRequested: {
            print("***** share requested", transfer)
            var filePath = String(transfer.items[0].url).replace('file://', '')
            qrCodeReader.processImage(filePath, m_name, m_issuer);
        }
    }

    property list<ContentItem> importItems
    property var activeTransfer: null
    property bool decodingImage: false
    ContentPeer {
        id: picSourceSingle
        contentType: ContentType.Pictures
        handler: ContentHandler.Source
        selectionType: ContentTransfer.Single
    }
    ContentTransferHint {
        id: importHint
        anchors.fill: parent
        activeTransfer: mainView.activeTransfer
        z: 100
    }
    Connections {
        target: mainView.activeTransfer
        onStateChanged: {
            switch (mainView.activeTransfer.state) {
            case ContentTransfer.Charged:
                print("should process", activeTransfer.items[0].url)
                mainView.decodingImage = true;
                qrCodeReader.processImage(activeTransfer.items[0].url, m_name, m_issuer);
                mainView.activeTransfer = null;
                break;
            case ContentTransfer.Aborted:
                mainView.activeTransfer = null;
                break;
            }
        }
    }

    onDecodingImageChanged: {
        if (!decodingImage && !qrCodeReader.valid) {
            pageStack.push(errorPageComponent)
        }
    }

    Component {
        id: errorPageComponent
        Page {
            title: i18n.tr("Error")
            Column {
                anchors {
                    left: parent.left;
                    right: parent.right;
                    verticalCenter: parent.verticalCenter
                }
                Label {
                    anchors { left: parent.left; right: parent.right }
                    horizontalAlignment: Text.AlignHCenter
                    // TRANSLATORS: Displayed after a picture has been scanned and no code was found in it
                    text: i18n.tr("No code found in image")
                }
            }
        }
    }

    Component {
        id: cardWalletComponent
        
        Page {
            id: cardWalletPage            
            
            header: PageHeader {
                id: cardWalletHeader
                title: i18n.tr("UBcards")
                leadingActionBar.actions: []
                trailingActionBar.actions: [
                    Action {
                        text: i18n.tr("About")
                        iconName: "info"
                        onTriggered: {
                            pageStack.push(aboutComponent)
                        }
                    }
                ]
            }
            
            BottomEdge {
                id: bottomEdge
                height: parent.height
                hint.text: i18n.tr("Add New Card")
                contentComponent: Rectangle {
                    width: cardWalletPage.width
                    height: cardWalletPage.height
                    
                    PageHeader {
                        title: "Add New Card"
                        id: addNewCardPageHeader
                        trailingActionBar.actions: [
                            Action {
                                // TRANSLATORS: Name of an action in the toolbar to import pictures from other applications and scan them for codes
                                text: i18n.tr("Import image")
                                iconName: "insert-image"
                                onTriggered: {
                                    m_name = newCardName.text
                                    m_issuer = newCardIssuer.text
                                    mainView.activeTransfer = picSourceSingle.request()
                                    print("transfer request", mainView.activeTransfer)
                                }
                            },
                            Action {
                                // TRANSLATORS: Name of an action in the toolbar to scan barcode
                                text: i18n.tr("Scan Card")
                                iconName: "camera-photo-symbolic"
                                onTriggered: {
                                    onTriggered: pageStack.push(qrCodeReaderComponent)
                                }
                            }
                        ]
                    }
                    
                    Flickable {
                        id: flickable
                
                        flickableDirection: Flickable.AutoFlickIfNeeded
                        anchors.fill: parent
                        anchors.topMargin: addNewCardPageHeader.height
                         anchors.bottomMargin: units.gu(5)
                        contentHeight: accountEditColumn.height
                
                        Column {
                            id: accountEditColumn
                
                            spacing: units.gu(1.5)
                            anchors {
                                top: parent.top; left: parent.left; right: parent.right; margins: units.gu(2)
                            }

                            Item {
                                 width: parent.width
                                 height: newCardNameLabel.height
                    
                                Label {
                                    id: newCardNameLabel
                                    text: i18n.tr("Insert card name:")
                                    font.pointSize: units.gu(1.5)
                                }
                            }
                            
                            Item {
                                 width: parent.width
                                 height: newCardName.height
                    
                                TextEdit {
                                    id: newCardName
                                    // TRANSLATORS: Default Card Name
                                    text: i18n.tr("Card-Name")
                                    font.pointSize: units.gu(2)
                                    wrapMode: TextEdit.WrapAnywhere
                                    inputMethodHints: Qt.ImhNoPredictiveText
                                    width: parent.width
                                    readOnly: false
                                }
                            }
                            
                            Item {
                                 width: parent.width
                                 height: newCardIssuerLabel.height
                    
                                Label {
                                    id: newCardIssuerLabel
                                    text: i18n.tr("Insert card issuer:")
                                    font.pointSize: units.gu(1.5)
                                }
                            }
                            
                            Item {
                                width: parent.width
                                height: newCardIssuer.height
                                 
                                TextEdit {
                                    id: newCardIssuer
                                    // TRANSLATORS: Default Card Issuer name
                                    text: i18n.tr("Card-Issuer")
                                    font.pointSize: units.gu(2)
                                    wrapMode: TextEdit.WrapAnywhere
                                    inputMethodHints: Qt.ImhNoPredictiveText
                                    width: parent.width
                                    readOnly: false
                                }
                            }
                            
                            Item {
                                 width: parent.width
                                 height: units.gu(2)
                            }
                            
                            Item {
                                 width: parent.width
                                 height: newCardNotice.height
                                 anchors {
                                     left: parent.left
                                     right: parent.right
                                 }
                                 
                    
                                Label {
                                    id: newCardNotice
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        margins: units.gu(2)
                                        horizontalCenter: parent.horizontalCenter
                                    }
                                    wrapMode: Text.Wrap
                                    text: i18n.tr("Set card type and card ID manually to edit-boxes below OR scan code using icons above.")
                                    font.pointSize: units.gu(2.5)
                                }
                            }
                            
                            Item {
                                 width: parent.width
                                 height: units.gu(2)
                            }
                            
                            Item {
                                 width: parent.width
                                 height: newCardTypeLabel.height
                    
                                Label {
                                    id: newCardTypeLabel
                                    text: i18n.tr("Select card type:")
                                    font.pointSize: units.gu(1.5)
                                }
                            }
                            
                            Item {
                                width: parent.width
                                height: newCardType.height
                                 
                                TextEdit {
                                    id: newCardType
                                    text: i18n.tr("CODE-128")
                                    font.pointSize: units.gu(2)
                                    wrapMode: TextEdit.WrapAnywhere
                                    inputMethodHints: Qt.ImhNoPredictiveText
                                    width: parent.width
                                    readOnly: false
                                }
                            }
                            
                            Item {
                                 width: parent.width
                                 height: newCardIDLabel.height
                    
                                Label {
                                    id: newCardIDLabel
                                    text: i18n.tr("Set card ID:")
                                    font.pointSize: units.gu(1.5)
                                }
                            }
                            
                            Item {
                                width: parent.width
                                height: newCardID.height
                                 
                                TextEdit {
                                    id: newCardID
                                    text: ""
                                    font.pointSize: units.gu(2)
                                    wrapMode: TextEdit.WrapAnywhere
                                    inputMethodHints: Qt.ImhNoPredictiveText
                                    width: parent.width
                                    readOnly: false
                                }
                            }
                    
                            Button {
                                width: parent.width
                                text: "Insert Card"
                                color: LomiriColors.green
                                onClicked: {
                                    bottomEdge.collapse()
                                    qrCodeReader.insertData(newCardID.text, newCardType.text, newCardName.text, newCardIssuer.text);
                                }
                            }
                    /*
                            Button {
                                width: parent.width
                                text: "Collapse"
                                onClicked: bottomEdge.collapse()
                            }*/
                    
                        }
                         
                    }
                    
                }
                
            }
            
            Flickable {
                id: flickable
                
                flickableDirection: Flickable.AutoFlickIfNeeded
                anchors.fill: parent
            
                ListView {
                    anchors.fill: parent
                    anchors.topMargin: cardWalletHeader.height
                    model: qrCodeReader.history
                
                    delegate: ListItem {
                        height: units.gu(10)
                
                        leadingActions: ListItemActions {
                            actions: [
                                Action {
                                    iconName: "delete"
                                    onTriggered: {
                                        qrCodeReader.history.remove(index)
                                    }
                                }
                            ]
                        }
                
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: units.gu(1)
                            LomiriShape {
                                Layout.fillHeight: true
                                Layout.preferredWidth: height
                                image: Image {
                                    anchors.fill: parent
                                    source: model.imageSource
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text: model.name + " by " + model.issuer
                                    font.pointSize: units.gu(2)
                                    maximumLineCount: 2
                                }
                                Label {
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                    text:model.timestamp
                                }
                            }
                        }
                
                        onClicked: {
                            pageStack.push(editPageComponent, {type: model.type, text: model.text, name: model.name, issuer: model.issuer, imageSource: model.imageSource})
                        }
                    }
                }
            }
        }
    }
    
    Component {
        id: qrCodeReaderComponent
        
        Page {
            id: qrCodeReaderPage
            signal codeParsed(string type, string text)
            property var aboutPopup: null
            
            header: PageHeader {
                title: i18n.tr("Scan Card")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            pageStack.pop()
                        }
                    }
                ]
                trailingActionBar.actions: [
                    
                ]
            }

            Component.onCompleted: {
                qrCodeReader.scanRect = Qt.rect(mainView.mapFromItem(videoOutput, 0, 0).x, mainView.mapFromItem(videoOutput, 0, 0).y, videoOutput.width, videoOutput.height)
            }

            Camera {
                id: camera

//                flash.mode: torchButton.active ? Camera.FlashTorch : Camera.FlashOff
//                flash.mode: Camera.FlashTorch

                focus.focusMode: Camera.FocusContinuous
                focus.focusPointMode: Camera.FocusPointAuto

                /* Use only digital zoom for now as it's what phone cameras mostly use.
                       TODO: if optical zoom is available, maximumZoom should be the combined
                       range of optical and digital zoom and currentZoom should adjust the two
                       transparently based on the value. */
                property alias currentZoom: camera.digitalZoom
                property alias maximumZoom: camera.maximumDigitalZoom

                function startAndConfigure() {
                    start();
                    focus.focusMode = Camera.FocusContinuous
                    focus.focusPointMode = Camera.FocusPointAuto
                }
            }

            Connections {
                target: Qt.application
                onActiveChanged: if (Qt.application.active) camera.startAndConfigure()
            }

            Timer {
                id: captureTimer
                interval: 2000
                repeat: true
                running: true
                onTriggered: {
                    if (!qrCodeReader.scanning) {
//                        print("capturing");
                        qrCodeReader.grab(newCardName.text, newCardIssuer.text);
                    }
                }

                onRunningChanged: {
                    if (running) {
                        camera.startAndConfigure();
                    } else {
                        camera.stop();
                    }
                }
            }

            VideoOutput {
                id: videoOutput
                anchors {
                    fill: parent
                }
                fillMode: Image.PreserveAspectCrop

                orientation: {
                    var angle = Screen.primaryOrientation == Qt.PortraitOrientation ? -90 : 0;
                    angle += Screen.orientation == Qt.InvertedLandscapeOrientation ? 180 : 0;
                    return angle;
                }
                source: camera
                focus: visible
                visible: !mainView.decodingImage
            }
            PinchArea {
                id: pinchy
                anchors.fill: parent

                property real initialZoom
                property real minimumScale: 0.3
                property real maximumScale: 3.0
                property bool active: false

                onPinchStarted: {
                    print("pinch started!")
                    active = true;
                    initialZoom = camera.currentZoom;
                }
                onPinchUpdated: {
                    print("pinch updated")
                    var scaleFactor = MathUtils.projectValue(pinch.scale, 1.0, maximumScale, 0.0, camera.maximumZoom);
                    camera.currentZoom = MathUtils.clamp(initialZoom + scaleFactor, 1, camera.maximumZoom);
                }
                onPinchFinished: {
                    active = false;
                }
            }

            Icon {
                id: torchButton
                height: units.gu(6)
                width: height
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: units.gu(2)
                }
                name: camera.flash.mode === Camera.FlashVideoLight ? "torch-off" : "torch-on"
                color: "white"

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        print("torch is", camera.flash.mode)
                        print("set to", (camera.flash.mode === Camera.FlashVideoLight ? Camera.FlashOff : Camera.FlashVideoLight))
                        camera.flash.mode = (camera.flash.mode === Camera.FlashVideoLight ? Camera.FlashOff : Camera.FlashVideoLight)
                        print("is now:", camera.flash.mode)
                    }
                }
            }

            ActivityIndicator {
                anchors.centerIn: parent
                running: mainView.decodingImage
            }
            Label {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: units.gu(5)
                text: i18n.tr("Decoding image")
                visible: mainView.decodingImage
            }
        }
    }

    Component {
        id: editPageComponent
        Page {
            id: editPage
            property string type
            property string text
             /* Card provider like Tesco .. */
            property string issuer
            /* My Card name */
            property string name 
            property string imageSource

            property bool isUrl: editPage.text.match(/^[a-z0-9]+:[^\s]+$/)

            header: PageHeader {
                id: resultsHeader
                visible: !exportVCardPeerPicker.visible
                title: i18n.tr("Edit Card")
                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            pageStack.pop()
                        }
                    }
                ]
                trailingActionBar.actions: [
                    Action {
                        text: i18n.tr("Copy to clipboard")
                        iconName: "edit-copy"
                        onTriggered: {
                            Clipboard.push(editPage.text)
                        }
                    },
                    Action {
                        // TRANSLATORS: Name of an action in the toolbar to import show card code as QR code
                        text: i18n.tr("Show as QR code")
                        iconName: "share"
                        onTriggered: {
                            pageStack.push(showQRCodeComponent, {textData: editPage.text})
                        }
                    },
                    Action {
                        text: i18n.tr("Open URL")
                        visible: editPage.isUrl
                        iconName: "stock_website"
                        onTriggered: {
                            Qt.openUrlExternally(editPage.text)
                        }
                    }
                ]
            }
            
            Item {
                anchors.fill: parent
                anchors.topMargin: resultsHeader.height
                clip: true

                Flickable {
                    id: detailFlickable
                    anchors.fill: parent
                    contentHeight: resultsColumn.implicitHeight + units.gu(4)
                    interactive: contentHeight > height

                    GridLayout {
                        id: resultsColumn
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: units.gu(2)
                        }

                        columnSpacing: units.gu(1)
                        rowSpacing: units.gu(1)
                        /*columns: editPage.width > editPage.height ? 3 : 1*/
                        columns: 1

                        Row {
                            Layout.fillWidth: true
                            spacing: units.gu(1)
                            Item {
                                id: imageItem
                                width: units.gu(10)
                                height: portrait ? width : imageShape.height
                                property bool portrait: resultsImage.height > resultsImage.width

                                LomiriShape {
                                    id: imageShape
                                    anchors.centerIn: parent
                                    // ssh : ssw = h : w
                                    height: imageItem.portrait ? parent.height : resultsImage.height * width / resultsImage.width
                                    width: imageItem.portrait ? resultsImage.width * height / resultsImage.height : parent.width
                                    image: Image {
                                        id: resultsImage
                                        source: editPage.imageSource
                                    }
                                }
                            }

                            Column {
                                Label {
                                    text: i18n.tr("Name")
                                    font.bold: true
                                }
                                Label {
                                    text: editPage.name
                                }
                                Item {
                                    width: parent.width
                                    height: units.gu(1)
                                }

                                Label {
                                    text: i18n.tr("Issuer")
                                    font.bold: true
                                }
                                Label {
                                    text: editPage.issuer
                                }
                                Item {
                                    width: parent.width
                                    height: units.gu(1)
                                }
                                
                                width: (parent.width - parent.spacing) / 2
                                Label {
                                    text: i18n.tr("Code type")
                                    font.bold: true
                                }
                                Label {
                                    text: editPage.type
                                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                }
                            }

                        }
                        
                        /* Display barcodes for scanning */
                        
                        FontLoader {
                            id: font_type128
                            source: "../fonts/Code128_new.ttf"
                        }
                        
                        FontLoader {
                            id: font_ean13
                            source: "../fonts/ean13_new.ttf"
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            visible: (editPage.type === "CODE-128") ? true : false
                            text: Encoder.stringToBarcode('CODE-128', editPage.text)
                            font.family: font_type128.name
                            textFormat: Text.PlainText
                            fontSizeMode: Text.HorizontalFit
                            minimumPointSize: units.gu(5)
                            font.pointSize: units.gu(20)
                            horizontalAlignment: Text.AlignHCenter
                            anchors.margins: units.gu(1)
                        }
                        
                        Text {
                            Layout.fillWidth: true
                            visible: (editPage.type === "EAN-13") ? true : false
                            text: Encoder.stringToBarcode('EAN-13', editPage.text)
                            font.family: font_ean13.name
                            textFormat: Text.PlainText
                            fontSizeMode: Text.HorizontalFit
                            minimumPointSize: units.gu(5)
                            font.pointSize: units.gu(20)
                            horizontalAlignment: Text.AlignHCenter
                            anchors.margins: units.gu(1)
                        }
                        
                        /* This should be visible only if code-type generation is not available */
                        Image {
                            Layout.fillWidth: true
                            id: cardCodeImage
                            visible: ((editPage.type === "CODE-128") || (editPage.type === "EAN-13")) ? false : true
                            source: editPage.imageSource
                        }
                        
                        /* Common string representation of the Code */
                        Label {
                            Layout.fillWidth: true
                            id: cardCodeContent
                            text: editPage.text
                            color: editPage.isUrl ? "blue" : "black"
                            textFormat: Text.PlainText
                            fontSizeMode: Text.HorizontalFit
                            minimumPointSize: units.gu(2)
                            font.pointSize: units.gu(5)
                            horizontalAlignment: Text.AlignHCenter
                            anchors.margins: units.gu(1)
                        }
                    }
                }
            }

            ContentItem {
                id: exportItem
                name: i18n.tr("Contact")
            }

            ContentPeerPicker {
                id: exportVCardPeerPicker
                visible: false
                contentType: ContentType.Contacts
                handler: ContentHandler.Destination
                anchors.fill: parent

                onPeerSelected: {
                    var transfer = peer.request();
                    if (transfer.state === ContentTransfer.InProgress) {
                        var items = new Array()
                        var path = fileHelper.saveToFile(editPage.text, "vcf")
                        exportItem.url = path
                        items.push(exportItem);
                        transfer.items = items;
                        transfer.state = ContentTransfer.Charged;
                    }
                    exportVCardPeerPicker.visible = false
                }
                onCancelPressed: exportVCardPeerPicker.visible = false
            }
        }
    }

    Component {
        id: showQRCodeComponent
        Page {
            id: showQRCodePage
            property string textData
            property var transfer: null

            header: PageHeader {
                id: generateQRCodeHeader
                title: i18n.tr("QR code")
                visible: !contentPeerPicker.visible

                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            if (transfer == null) {
                                pageStack.pop()
                            } else {
                                transfer.state = ContentTransfer.Aborted
                            }
                        }
                    }
                ]

                trailingActionBar.actions: [
                    Action {
                        iconName: "share"
                        onTriggered: {
                            Qt.inputMethod.hide();
                            contentPeerPicker.visible = true;
                        }
                        visible: transfer == null && textData
                    }
                ]
            }


            ContentItem {
                id: exportItem
                name: i18n.tr("QR-Code")
            }

            QRCodeGenerator {
                id: generator
            }

            GridLayout {
                anchors {
                    fill: parent
                    margins: units.gu(1)
                    topMargin: generateQRCodeHeader.height + units.gu(1)
                }
                columnSpacing: units.gu(1)
                rowSpacing: units.gu(1)
                columns: width > height ? 2 : 1

                Image {
                    id: qrCodeImage
                    Layout.preferredWidth: Math.min(parent.width, parent.height)
                    Layout.preferredHeight: width
                    fillMode: Image.PreserveAspectFit
                    source: textData.length > 0 ? "image://qrcode/" + textData : ""
                    onStatusChanged: print("status changed", status)
                }
            }
            
             ContentPeerPicker {
                id: contentPeerPicker
                visible: false
                contentType: ContentType.Pictures
                handler: ContentHandler.Share
                anchors.fill: parent

                onPeerSelected: {
                    var transfer = peer.request();
                    if (transfer.state === ContentTransfer.InProgress) {
                        var items = new Array()
                        var path = generator.generateCode("export.png", textData)
                        exportItem.url = path
                        items.push(exportItem);
                        transfer.items = items;
                        transfer.state = ContentTransfer.Charged;
                    }
                    contentPeerPicker.visible = false
                }
                onCancelPressed: contentPeerPicker.visible = false
            }
        }
    }
    
    Component {
        id: aboutComponent
        
        Page {
            id: aboutPage

            header: PageHeader {
                id: generateQRCodeHeader
                title: i18n.tr("About")

                leadingActionBar.actions: [
                    Action {
                        iconName: "back"
                        onTriggered: {
                            pageStack.pop()
                        }
                    }
                ]
            }
            
            Flickable {
            id: flickable
            
            flickableDirection: Flickable.AutoFlickIfNeeded
            anchors.fill: parent
            contentHeight: dataColumn.height + units.gu(10) + dataColumn.anchors.topMargin
            
                Column {
                    id: dataColumn
                
                    spacing: units.gu(3)
                    anchors {
                        top: parent.top; left: parent.left; right: parent.right; topMargin: units.gu(10); rightMargin:units.gu(2.5); leftMargin: units.gu(2.5)
                    }
                
                    LomiriShape {
                        width: units.gu(20)
                        height: width
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            topMargin: units.gu(20)
                        }
                        source: Image {
                           source: "../graphics/tagger.png"
                        }
                
                    }
                
                    Label {
                        width: parent.width
                        textSize: Label.XLarge
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        text: "UBcards"
                    }
                
                    Column {
                        width: parent.width
                
                        Label {
                            id: appVersionLabel
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            // TRANSLATORS: Version number
                            text: i18n.tr("App Version %1").arg(Qt.application.version)
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: " "
                        }
                        LabelLinkRow {
                            id: maintainerLabel
                            //width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            labeltext: i18n.tr("Maintained by")
                            linktext: i18n.tr("Jan Belohoubek")
                            linkurl: "https://github.com/belohoub/UBcards"
                        }
                        Label {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: " "
                        }
                        LabelLinkRow {
                            id: issueReportLabel
                            //width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            labeltext: i18n.tr("Please report bugs to the")
                            linktext: i18n.tr("issue tracker")
                            linkurl: "https://github.com/belohoub/UBcards/issues"
                        }
                        
                        LabelLinkRow {
                            id: supportReportLabel
                            //width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            labeltext: i18n.tr("Please support")
                            linktext: i18n.tr("the app development")
                            linkurl: "https://github.com/sponsors/belohoub"
                        }
                    }
                
                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            margins: units.gu(2)
                        }
                        Label {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            text: i18n.tr("Thanks to")
                        }
                
                        LabelLinkRow {
                            id: taggerAppLabel
                            //width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            labeltext: i18n.tr("Chris Clime, Tagger application:")
                            linktext: "Tagger Application"
                            linkurl: "https://gitlab.com/balcy/tagger"
                        }
                        LabelLinkRow {
                            id: cwAppLabel
                            //width: parent.width
                            anchors.horizontalCenter: parent.horizontalCenter
                            labeltext: i18n.tr("Richard Lee, Card Wallet application:")
                            linktext: "Card Wallet"
                            linkurl: "https://gitlab.com/AppsLee/cardwallet"
                        }
                    }
                    Label {
                        textSize: Label.Small
                        width: parent.width
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: i18n.tr("Released under the terms of the GNU GPLv3")
                    }
                    LabelLinkRow {
                        id: sourceCodeLabel
                        //width: parent.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        labeltext: i18n.tr("Source code available on:")
                        linktext: "github.com/belohoub/UBcards"
                        linkurl: "https://github.com/belohoub/UBcards"
                    }
                }
            }
        }
    }
}