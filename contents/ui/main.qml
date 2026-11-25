import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.ksysguard.sensors as Sensors
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    property real cpuPercent: 0
    property real gpuPercent: 0
    property real downloadMbps: 0
    property real uploadMbps: 0

    readonly property color cpuColor: plasmoid.configuration.cpuColor
    readonly property color gpuColor: plasmoid.configuration.gpuColor
    readonly property color downloadColor: plasmoid.configuration.downloadColor
    readonly property color uploadColor: plasmoid.configuration.uploadColor
    readonly property color trackColor: plasmoid.configuration.trackColor

    readonly property real maxDownloadMbps: plasmoid.configuration.maxDownloadMbps
    readonly property real maxUploadMbps: plasmoid.configuration.maxUploadMbps
    readonly property int updateMs: Math.max(500, (plasmoid.configuration.updateInterval || 2) * 1000)
    readonly property string configuredIface: (plasmoid.configuration.networkInterface || "").trim()
    readonly property string netPrefix: configuredIface.length > 0 ? ("network/" + configuredIface + "/") : "network/all/"

    toolTipMainText: ""
    toolTipSubText: ""

    function formatMbps(mbps) {
        if (mbps >= 1000) return (mbps / 1000).toFixed(2) + " Gbps"
        if (mbps >= 1) return mbps.toFixed(1) + " Mbps"
        if (mbps > 0) {
            var kbps = mbps * 1000
            if (kbps >= 1) return kbps.toFixed(0) + " Kbps"
            return (kbps * 1000).toFixed(0) + " bps"
        }
        return "0 Mbps"
    }

    Sensors.Sensor {
        id: cpuSensor
        sensorId: "cpu/all/usage"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.cpuPercent = Math.max(0, Math.min(100, Number(value)))
            }
        }
    }

    Sensors.Sensor {
        id: gpuSensor
        sensorId: "gpu/all/usage"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.gpuPercent = Math.max(0, Math.min(100, Number(value)))
            }
        }
    }

    Sensors.Sensor {
        id: netDownSensor
        sensorId: root.netPrefix + "download"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.downloadMbps = Math.max(0, Number(value) * 8 / 1000000)
            }
        }
    }

    Sensors.Sensor {
        id: netUpSensor
        sensorId: root.netPrefix + "upload"
        updateRateLimit: root.updateMs
        enabled: true
        onValueChanged: {
            if (value !== undefined && !isNaN(value)) {
                root.uploadMbps = Math.max(0, Number(value) * 8 / 1000000)
            }
        }
    }

    component StatBar: ColumnLayout {
        id: barRoot
        property string label: ""
        property string valueText: ""
        property real ratio: 0
        property color barColor: "#ff2fc0"

        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing / 2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: barRoot.label
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            PlasmaComponents3.Label {
                text: barRoot.valueText
                font.bold: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 0.55
            radius: height / 2
            color: root.trackColor

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                radius: parent.radius
                color: barRoot.barColor
                width: Math.max(0, Math.min(1, barRoot.ratio)) * parent.width

                Behavior on width {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRepItem

        Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: plasmoid.configuration.popupWidth
        Layout.preferredHeight: plasmoid.configuration.popupHeight
        spacing: Kirigami.Units.smallSpacing * 2

        onWidthChanged: resizeSaveTimer.restart()
        onHeightChanged: resizeSaveTimer.restart()

        Timer {
            id: resizeSaveTimer
            interval: 250
            repeat: false
            onTriggered: {
                if (plasmoid.expanded && fullRepItem.Window.window && fullRepItem.Window.window.visible) {
                    if (fullRepItem.width >= fullRepItem.Layout.minimumWidth && fullRepItem.width !== plasmoid.configuration.popupWidth) {
                        plasmoid.configuration.popupWidth = fullRepItem.width;
                    }
                    if (fullRepItem.height >= fullRepItem.Layout.minimumHeight && fullRepItem.height !== plasmoid.configuration.popupHeight) {
                        plasmoid.configuration.popupHeight = fullRepItem.height;
                    }
                }
            }
        }

        StatBar {
            label: "CPU"
            valueText: root.cpuPercent.toFixed(0) + "%"
            ratio: root.cpuPercent / 100
            barColor: root.cpuColor
        }

        StatBar {
            label: "GPU"
            valueText: root.gpuPercent.toFixed(0) + "%"
            ratio: root.gpuPercent / 100
            barColor: root.gpuColor
        }

        StatBar {
            label: "Download"
            valueText: root.formatMbps(root.downloadMbps)
            ratio: root.maxDownloadMbps > 0 ? root.downloadMbps / root.maxDownloadMbps : 0
            barColor: root.downloadColor
        }

        StatBar {
            label: "Upload"
            valueText: root.formatMbps(root.uploadMbps)
            ratio: root.maxUploadMbps > 0 ? root.uploadMbps / root.maxUploadMbps : 0
            barColor: root.uploadColor
        }
    }

    // Small icon-style bars used when the plasmoid sits in a panel.
    compactRepresentation: Item {
        id: compact

        readonly property bool isPanelVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property bool isVerticalLayout: {
            var opt = plasmoid.configuration.displayOrientation;
            if (opt === 1) return false;
            if (opt === 2) return true;
            return compact.isPanelVertical;
        }

        readonly property int barThickness: plasmoid.configuration.barThickness
        readonly property int barGap: 3
        readonly property int margin: 4
        readonly property int barLength: plasmoid.configuration.barLength

        Layout.fillWidth: compact.isPanelVertical
        Layout.preferredWidth: {
            if (compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                return compact.barThickness * 4 + compact.barGap * 3 + compact.margin * 2;
            } else {
                return compact.barLength;
            }
        }
        Layout.minimumWidth: Layout.preferredWidth

        Layout.fillHeight: !compact.isPanelVertical
        Layout.preferredHeight: {
            if (!compact.isPanelVertical) {
                return -1;
            }
            if (compact.isVerticalLayout) {
                return compact.barLength;
            } else {
                return compact.barThickness * 4 + compact.barGap * 3 + compact.margin * 2;
            }
        }
        Layout.minimumHeight: Layout.preferredHeight

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        component CompactBar: Rectangle {
            id: barItem
            property real ratio: 0
            property color barColor: "#ffffff"
            property bool verticalFill: false

            Layout.fillWidth: !verticalFill
            Layout.fillHeight: verticalFill
            Layout.preferredWidth: verticalFill ? compact.barThickness : -1
            Layout.preferredHeight: verticalFill ? -1 : compact.barThickness
            radius: (verticalFill ? width : height) / 2
            color: root.trackColor
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.top: barItem.verticalFill ? undefined : parent.top
                anchors.right: barItem.verticalFill ? parent.right : undefined
                radius: parent.radius
                color: barItem.barColor
                width: barItem.verticalFill ? parent.width : Math.max(0, Math.min(1, barItem.ratio)) * parent.width
                height: barItem.verticalFill ? Math.max(0, Math.min(1, barItem.ratio)) * parent.height : parent.height
                Behavior on width { enabled: !barItem.verticalFill; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on height { enabled: barItem.verticalFill; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        // Horizontal layout (horizontal bars, stacked):
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - compact.margin * 2
            spacing: compact.barGap
            visible: !compact.isVerticalLayout

            CompactBar { ratio: root.cpuPercent / 100; barColor: root.cpuColor; verticalFill: false }
            CompactBar { ratio: root.gpuPercent / 100; barColor: root.gpuColor; verticalFill: false }
            CompactBar { ratio: root.maxDownloadMbps > 0 ? root.downloadMbps / root.maxDownloadMbps : 0; barColor: root.downloadColor; verticalFill: false }
            CompactBar { ratio: root.maxUploadMbps > 0 ? root.uploadMbps / root.maxUploadMbps : 0; barColor: root.uploadColor; verticalFill: false }
        }

        // Vertical layout (vertical bars, side-by-side):
        RowLayout {
            anchors.centerIn: parent
            height: parent.height - compact.margin * 2
            spacing: compact.barGap
            visible: compact.isVerticalLayout

            CompactBar { ratio: root.cpuPercent / 100; barColor: root.cpuColor; verticalFill: true }
            CompactBar { ratio: root.gpuPercent / 100; barColor: root.gpuColor; verticalFill: true }
            CompactBar { ratio: root.maxDownloadMbps > 0 ? root.downloadMbps / root.maxDownloadMbps : 0; barColor: root.downloadColor; verticalFill: true }
            CompactBar { ratio: root.maxUploadMbps > 0 ? root.uploadMbps / root.maxUploadMbps : 0; barColor: root.uploadColor; verticalFill: true }
        }
    }
}
