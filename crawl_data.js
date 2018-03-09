var url ='http://static.bacalaureat.edu.ro/2017/rapoarte/rezultate/alfabetic/index.html';
var page = require('webpage').create();
page.open(url, function(status) {});


page.onLoadFinished = function() {
  console.log("loaded");

  var isLast = page.evaluate(function() {
    console.log("called");
    var table = document.getElementById('mainTable')
      .childNodes[1];
    console.log(table.innerHTML);

    /*
    var rows = table.childNodes[1].getElementsByTagName('tr');

    for (var i = 1; i < rows.length; ++i) {
      var cols = rows[i].getElementsByTagName('td');
      // console.log(cols[2].innerHTML);
      console.log(cols[1].innerHTML);
    }

    var btn = document.getElementById('ContentPlaceHolderBody_ImageButtonDR1');
    if (!btn) {
      return 1;
    }
    // btn.click();
    return 0;
    return 1;*/
  });
  if (true) {
    phantom.exit();
  }
};

page.onConsoleMessage = function(msg) {
  var fs = require('fs');
  var path = 'tst.txt';
  fs.write(path, msg + "\n", 'a+');
    system.stderr.writeLine('console: ' + msg);
};
