//Outside imports
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

//Local imports
import 'GoogleMapsServices.dart';
import 'convertToLatLng.dart';
import 'decodePoly.dart';
import 'removeAllHtmlTags.dart';

//Initializing functions
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edirne Eczane',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

//Main page state
class _MapViewState extends State<MapView> {
  //Variables - Start ----------------------------------------------------------1S

  //Google Maps tools
  GoogleMapsServices _googleMapsServices = GoogleMapsServices();
  GoogleMapController mapController;

  //Default camera position
  CameraPosition _initialLocation =
      CameraPosition(target: LatLng(41.6764, 26.5572), zoom: 12);

  //Initial location data
  Position _currentPosition;

  //Markers data
  Set<Marker> markers = {};

  //Parsed data
  List<String> pharmacyNames = [];
  List<double> latCoords = [];
  List<double> lngCoords = [];
  List<String> descriptions = [];
  List<String> phones = [];

  //PolyLines for directions
  final Set<Polyline> _polyLines = {};
  Set<Polyline> get polyLines => _polyLines;

  //Variables - End ------------------------------------------------------------1E

  //Async functions - Start ----------------------------------------------------2S

  //Creates map directions from user location to target
  void sendRequest(double lat, double lng) async {
    LatLng start =
        LatLng(_currentPosition.latitude, _currentPosition.longitude);
    LatLng destination = LatLng(lat, lng);
    String route =
        await _googleMapsServices.getRouteCoordinates(start, destination);
    createRoute(route);
  }

  //Draws the polyLines on the map from the directions data
  void createRoute(String encodedPoly) {
    setState(() {
      _polyLines.clear();
      _polyLines.add(Polyline(
          polylineId: PolylineId(_currentPosition.toString()),
          width: 4,
          points: convertToLatLng(decodePoly(encodedPoly)),
          color: Colors.red));
    });
  }

  //Parses the required pharmacy data
  _getData() async {
    final response = await http.Client()
        .get(Uri.parse('https://www.edirneeo.org.tr/nobetci-eczaneler'));
    if (response.statusCode == 200) {
      var document = parse(response.body);

      //Gets pharmacy names and adds them to a list
      var pharmacyNamesHtml = document.getElementsByClassName('kirmizi');
      for (var item in pharmacyNamesHtml) {
        pharmacyNames.add(removeAllHtmlTags(item.innerHtml.toString()).trim());
      }

      //Gets coordinates and descriptions
      var allHrefs = document.getElementsByClassName('nine columns top-1');
      List<String> fullCoords = [];
      for (var i in allHrefs) {
        //Gets raw string coordinate data
        var temp = i
            .getElementsByTagName('a')
            .where((e) => e.attributes.containsKey('href'))
            .map((e) => e.attributes['href'])
            .toList();
        fullCoords.add(temp[0].substring(31, temp[0].length));

        //Gets district, address and phone number
        var temp2 = removeAllHtmlTags(i.getElementsByTagName('p').last.text)
            .replaceAll(RegExp(' {2,}'), '')
            .replaceAll(RegExp('\n\n\n'), '\n')
            .replaceAll('					 Nöbet Kartı Yazdır\n', '');
        descriptions.add(temp2);

        final startIndex = temp2.indexOf('284');
        final endIndex = startIndex + 10;
        phones.add('+90' + temp2.substring(startIndex, endIndex));
        print(phones);
      }

      //Sets raw string coordinates to double LatLng values
      for (var i in fullCoords) {
        var split = i.split(',');
        latCoords.add(double.parse(split[0]));
        lngCoords.add(double.parse(split[1]));
      }

      //Sets markers for every pharmacy on the map for the parsed data above
      for (int i = 0; i < pharmacyNames.length; i++) {
        setState(() {
          markers.add(Marker(
            markerId: MarkerId(pharmacyNames[i]),
            position: LatLng(latCoords[i], lngCoords[i]),
            infoWindow:
                InfoWindow(title: pharmacyNames[i], snippet: "Yol tarifi..."),

            //Draws polyLines and shows the directions when the marker is tapped
            onTap: () {
              _getCurrentLocation();
              sendRequest(latCoords[i], lngCoords[i]);
            },
          ));
        });
      }
    } else
      throw Exception();
  }

  //Gets user's current position
  _getCurrentLocation() async {
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        _initialLocation = CameraPosition(
            target: LatLng(position.latitude, position.longitude), zoom: 10);
      });
    }).catchError((e) {
      print(e);
    });
  }

  //Async functions - End ------------------------------------------------------2E

  //Main App - Start -----------------------------------------------------------3S

  //Initial states
  @override
  void initState() {
    super.initState();
    _getData();
    _getCurrentLocation();
  }

  //Builds the main window
  @override
  Widget build(BuildContext context) {
    //User device's height and width
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Container(
      height: height,
      width: width,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Eczaneler'),
        ),

        //Drawer for listing all available pharmacies
        drawer: Drawer(
            child: new ListView.builder(
                itemCount: pharmacyNames.length,
                itemBuilder: (BuildContext context, int index) {
                  //Attaches a header to the first item on the list
                  if (index == 0) {
                    return Column(
                      children: <Widget>[
                        Padding(
                            padding: EdgeInsets.only(top: 30, bottom: 20),
                            child: Text('Eczane Listesi',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 25))),

                        //Creates a pressable button for the first pharmacy
                        TextButton(
                          onPressed: () {},
                          child: ListTile(
                            leading: Image(
                                image: AssetImage('images/eczaneMarker.png'),
                                height: 50,
                                width: 50),

                            //Shows name, district, address and phone number
                            title: Text(pharmacyNames[index],
                                style: TextStyle(fontSize: 18)),
                            subtitle: Column(children: <Widget>[
                              Text(descriptions[index]),
                              Row(children: <Widget>[
                                //Phone calls the pharmacy when tapped
                                GestureDetector(
                                  onTap: () {
                                    launch("tel://" + phones[index]);
                                  },
                                  child: Image.asset('images/phoneCall.png',
                                      scale: 5.0),
                                ),
                                SizedBox(
                                  width: 6,
                                ),
                                Text("Ara"),
                                SizedBox(
                                  width: 10,
                                ),
                                //Shows the pharmacy on the map when tapped
                                GestureDetector(
                                  onTap: () {
                                    mapController.moveCamera(
                                        CameraUpdate.newLatLng(LatLng(
                                            latCoords[index],
                                            lngCoords[index])));
                                    _getCurrentLocation();
                                    sendRequest(
                                        latCoords[index], lngCoords[index]);
                                    Navigator.of(context).pop();
                                  },
                                  child: Image.asset('images/location.png',
                                      scale: 5.0),
                                ),
                                SizedBox(
                                  width: 6,
                                ),
                                Column(
                                  children: [
                                    Text("Haritada"),
                                    Text("Göster"),
                                  ],
                                )
                              ]),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }

                  //Creates a pressable button for every other pharmacy
                  return TextButton(
                    onPressed: () {},
                    child: ListTile(
                      leading: Image(
                          image: AssetImage('images/eczaneMarker.png'),
                          height: 50,
                          width: 50),

                      //Shows name, district, address and phone number
                      title: Text(pharmacyNames[index],
                          style: TextStyle(fontSize: 18)),
                      subtitle: Column(children: <Widget>[
                        Text(descriptions[index]),
                        Row(children: <Widget>[
                          //Phone calls the pharmacy when tapped
                          GestureDetector(
                            onTap: () {
                              launch("tel://" + phones[index]);
                            },
                            child:
                                Image.asset('images/phoneCall.png', scale: 5.0),
                          ),
                          SizedBox(
                            width: 6,
                          ),
                          Text("Ara"),
                          SizedBox(
                            width: 10,
                          ),
                          //Shows the pharmacy on the map when tapped
                          GestureDetector(
                            onTap: () {
                              mapController.moveCamera(CameraUpdate.newLatLng(
                                  LatLng(latCoords[index], lngCoords[index])));
                              _getCurrentLocation();
                              sendRequest(latCoords[index], lngCoords[index]);
                              Navigator.of(context).pop();
                            },
                            child:
                                Image.asset('images/location.png', scale: 5.0),
                          ),
                          SizedBox(
                            width: 6,
                          ),
                          Column(
                            children: [
                              Text("Haritada"),
                              Text("Göster"),
                            ],
                          )
                        ]),
                      ]),
                    ),
                  );
                })),

        //Builds the main map
        body: Stack(
          children: <Widget>[
            GoogleMap(
              markers: markers != null ? Set<Marker>.from(markers) : null,
              polylines: _polyLines,
              initialCameraPosition: _initialLocation,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
          ],
        ),
      ),
    );
  }
  //Main App - End -------------------------------------------------------------3S
}
