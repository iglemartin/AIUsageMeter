import QtQuick

// Circular progress ring with optional text in the center.
Item {
    id: ring

    property real value: 0                       // 0..100
    property real lineWidth: Math.max(2, Math.min(width, height) * 0.13)
    property color trackColor: Qt.rgba(0.5, 0.5, 0.5, 0.30)
    property color progressColor: "#888888"
    property string centerText: ""
    property color textColor: progressColor
    property bool showText: true

    implicitWidth: 24
    implicitHeight: 24

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var w = width;
            var h = height;
            var cx = w / 2;
            var cy = h / 2;
            var r = Math.min(w, h) / 2 - ring.lineWidth / 2 - 1;
            if (r <= 0)
                return;

            // background track
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.lineWidth = ring.lineWidth;
            ctx.strokeStyle = ring.trackColor;
            ctx.stroke();

            // progress
            var frac = Math.max(0, Math.min(1, ring.value / 100));
            if (frac > 0) {
                var start = -Math.PI / 2;
                ctx.beginPath();
                ctx.arc(cx, cy, r, start, start + frac * 2 * Math.PI);
                ctx.lineWidth = ring.lineWidth;
                ctx.lineCap = "round";
                ctx.strokeStyle = ring.progressColor;
                ctx.stroke();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: ring.showText && text.length > 0
        text: ring.centerText
        color: ring.textColor
        font.bold: true
        font.pixelSize: Math.max(7, Math.min(ring.width, ring.height) * 0.32)
    }

    onValueChanged: canvas.requestPaint()
    onProgressColorChanged: canvas.requestPaint()
    onTrackColorChanged: canvas.requestPaint()
    onLineWidthChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()
}
