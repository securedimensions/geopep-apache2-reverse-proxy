// Create a group for overlays. Add the group to the map when it's created
// but add the overlay layers later
var overlayGroup = new ol.layer.Group({
        title: 'Overlays',
        layers: []
});

var layerSwitcher = new ol.control.LayerSwitcher();

var demoMap = new function () {

    // Private members
    var map = new ol.Map({
        layers: [
            new ol.layer.Tile({
                source: new ol.source.OSM()
            }),
            overlayGroup
        ],
        target: "map",
        view: new ol.View({
            center: [-10997148, 4569099],
            zoom: 4
        })
    });

    // Set up the secured layer which can only be displayed when providing a valid access token
    var geoserver = new ol.source.TileWMS({
        url: "/geoserver/topp/wms",
        params: { 'LAYERS': "topp:states", 'TILED': true, 'VERSION': '1.1.1' },
        serverType: "geoserver"
    });

    var ogcLayer = null;

    // Public functions
    this.AddLayer = function () {
        ogcLayer = new ol.layer.Tile({
            title: 'Redacted WMS',
            extent: [-13884991, 2870341, -7455066, 6338219],
            source: geoserver
        });

        map.addControl(layerSwitcher);
        overlayGroup.getLayers().push(ogcLayer);

    };

    this.RemoveLayer = function () {
        overlayGroup.getLayers().clear();
        map.removeControl(layerSwitcher);
    };

};

