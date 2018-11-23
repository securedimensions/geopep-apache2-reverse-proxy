$(document).ready(function() {
    ;
});

// When the user clicks on login
$("#loginButton").on("click", function () {

        // Add the secured layer to the map for the first time
        demoMap.AddLayer();

        // Toggle the login / logout buttons
        $("#loginButton").hide();
        $("#logoutButton").show();

});

// When the user clicks on logout
$("#logoutButton").on("click",function() {

        // Remove the secured layer as it will not work without a valid access token anyway
        demoMap.RemoveLayer();

        // Toggle the login / logout buttons
        $("#logoutButton").hide();
        $("#loginButton").show();
});
