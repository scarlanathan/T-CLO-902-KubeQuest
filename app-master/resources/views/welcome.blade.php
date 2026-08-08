<!DOCTYPE html>
<html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Hello world sample app</title>
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'self'; script-src 'self' https://code.jquery.com 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; base-uri 'self'; frame-ancestors 'none'; object-src 'none'">
    <script
        src="https://code.jquery.com/jquery-3.7.0.min.js"
        integrity="sha256-2Pmvv0kuTBOenSvLm6bvfBSSHrUJ+3A7x6P5Ebd07/g="
        crossorigin="anonymous"></script>
    </head>
    <body>
        <h1>Hello world sample app</h1>
        <p>Counter :<p id="value">{{ $value }}</p></p>
        <button id="add">+1</button>

        <script>
            $(document).ready(function(){
                $("#add").click(function(e){
                    // L'incrémentation mute l'état -> POST (voir routes/api.php).
                    $.post("/api/counter/add", function(data){
                        $('#value').text(data.value);
                    });
                });
            });
        </script>
    </body>
</html>
