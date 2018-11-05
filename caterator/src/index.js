import './main.css';
import { Elm } from './Main.elm';
import registerServiceWorker from './registerServiceWorker';
// var Elm = require('./Main.elm')
// console.log(Main);
// console.log(Elm);
// console.log(Elm.Elm.Main);
var app = Elm.Main.init({node: document.getElementById('root')});

app.ports.fileSelected.subscribe(function (id) {
  var node = document.getElementById(id);
  console.log('in the js')
  if (node === null) {
    console.log('could not find node: ' + id);
    return;
  }
  var file = node.files[0];
  var reader = new FileReader();
  console.log('made a reader etc')
  reader.onload = (function(event) {
    console.log('should have loaded: ' + file.name);
    var encoded = event.target.result;
    var portData = {
      contents: encoded,
      filename: file.name
    };
    app.ports.fileContentRead.send(portData);
    console.log('sent it back to elm')
  });

  reader.readAsDataURL(file);
});

registerServiceWorker();
