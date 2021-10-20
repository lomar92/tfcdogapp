#!/bin/bash
# Script to deploy a very simple web application.
# The web app has a customizable image and some text.

cat << EOM > /var/www/html/index.html
<html>
  <head><title>Wooof!</title></head>
  <body>
  <div style="width:800px;margin: 0 auto">

  <!-- BEGIN -->
  <center><img src="http://placedog.net/800/600?random"></img></center>
  <center><h2>Dog rules!</h2></center>
  Welcome to ${PREFIX}'s app. Have fun with your dogs!
  <!-- END -->

  </div>
  </body>
</html>
EOM

echo "Script complete."