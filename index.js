'use strict';
const doc = require('dynamodb-doc');
const dynamodb = new doc.DynamoDB();

exports.handler = function(event, context) {
    if (event.request.type === "LaunchRequest") {
        getWelcomeResponse(
            function callback(sessionAttributes, speechletResponse) {
                context.succeed(buildResponse(sessionAttributes, speechletResponse));
        });

    } else if (event.request.type === "IntentRequest") {

        if (event.request.intent.name === "mainHelpIntent") {
          var dishes = "";
          dynamodb.scan({
              TableName : "Recipes"
          }, function(err, data) {
              if (err) {
                  context.done('error','reading dynamodb failed: '+err);
              }
              for (var i in data.Items) {
                  i = data.Items[i];
                  dishes += i.RecipeName + ', '
              }
              context.done(
                  getSearchTerms(dishes,
                      function callback(sessionAttributes, speechletResponse) {
                          context.succeed(buildResponse(sessionAttributes, speechletResponse));
                  })
              );
          });
        }

        else {
          var dishIngredients = [];
          var dishDirections = [];
          dynamodb.query({
              TableName : "Recipes",
              KeyConditionExpression: "#rec = :dish",
              ExpressionAttributeNames:{
                "#rec": "RecipeName"
              },
              ExpressionAttributeValues: {
                ":dish": "Pasta"
              }
          }, function(err, data) {
              if (err) {
                  context.done('error','reading dynamodb failed: '+err);
              }
              dishIngredients = (data.Items[0].Ingredients).split('\n');
              dishDirections = (data.Items[0].Directions).split('\n');
              context.done(
                  handleRecipeIntent(
                    dishIngredients,
                    dishDirections,
                    event.request.intent,
                    event.session,
                    function callback(sessionAttributes, speechletResponse) {
                        context.succeed(buildResponse(sessionAttributes, speechletResponse));
                    }
                  )
              );
          });
        }


        else if (event.request.intent.name === "quitIntent") {
          handleFinishSessionRequest(
            event.request.intent,
            event.session,
            function callback(sessionAttributes, speechletResponse) {
                context.succeed(buildResponse(sessionAttributes, speechletResponse));
            }
          );
        }  

    } else if (event.request.type === "SessionEndedRequest") {
        onSessionEnded(event.request, event.session);
        context.succeed();
    }
};

var CARD_TITLE = "Recipe Assistant";

function getWelcomeResponse(callback) {
    var sessionAttributes = {},
        speechOutput = "Recipe assistant, what recipe would you like to make?",
        shouldEndSession = false;

    sessionAttributes = {
        "speechOutput": speechOutput,
        "mode": "MAIN"
    };
    callback(sessionAttributes,
        buildSpeechletResponse(CARD_TITLE, speechOutput, shouldEndSession));
}

/*
  DynamoDB Scan 'RecipeName' column
*/

function getSearchTerms(dishes, callback) {
    var sessionAttributes = {},
        speechOutput = "You can say find or I'd like to make " + dishes,
        shouldEndSession = false;

    sessionAttributes = {
        "speechOutput": speechOutput,
        "mode": "MAIN"
    };
    callback(sessionAttributes,
        buildSpeechletResponse(CARD_TITLE, speechOutput, shouldEndSession));
}

function handleRecipeIntent(ingredients, directions, intent, session, callback) {

  /*
    Called when:  1. Finished with Main Dialog
                  2. 'ingredients'
                  3. 'what are the ingredients'
  */
  if (intent.name == "searchRecipeIntent") {
    var speechOutput = "The first ingredient is " + ingredients[0];
    var sessionAttributes = {
        "speechOutput": speechOutput,
        "mode": "INGREDIENTS",
        "currIngredient": 0,
        "currDirection": 0
    };

    callback(sessionAttributes,
        buildSpeechletResponse(CARD_TITLE, speechOutput, false));

  /*
    Retrieve session attributes
  */
  } else {
      var currIngredient = session.attributes.currIngredient,
          currDirection = session.attributes.currDirection,
          mode = session.attributes.mode,
          ingredientsLen = ingredients.size,
          directionsLen = directions.size;

    /*
    Called when:  1. Moved to Ingredients dialog
                  2. Moved to Directions dialog
    */
    if (intent.name == "handleRecipeIntent") {

        if (mode == "INGREDIENTS") {
          var nextIngredient = currIngredient++;

          // SAY FIRST INGREDIENT
          // PUT MODE TO INGREDIENT INITIALIZE SESSION ATTRIBUTES

        } else if (mode == "DIRECTIONS") {

          // SAY FIRST DIRECTIONS
          // PUT MODE TO DIRECTIONS, INITIALIZE SESSION, ATTRIBUTES

        }

    /*
      Called when:  1. increment/decrement Ingredients 
                    2. increment/decrement Directions 
    */
    } else if (intent.name == "incrementIntent") {

      // DEPENDING ON SLOT INCREMENT OR DECREASE, CREATE 
      // VAR NEXTSTEP = NEXT OR LAST THING

      if (mode == "INGREDIENTS") {


        // IF ON LAST INGREDIENT, SWITCH MODE TO DIRECTIONS AND DO HANDLE RECIPE INTENT?

      } else if (mode == "DIRECTIONS") {


      }

    /*
      Called when:  1. start Ingredients again
                    2. start Directions again
    */
    } else if (intent.name == "restartIntent") {

      if (mode == "INGREDIENTS") {

        // RESET SESSION ATTRIBUTE SSTART AT INGREDIENT 1


      } else if (mode == "DIRECTIONS") {

        // RESET SESSION ATTRIBUTE SSTART AT INGREDIENT 1

      }

    } else {
      callback(session.attributes,
        buildSpeechletResponse(CARD_TITLE, "Your request cannot be completed.", false));
    }
  }
}


/*
  MAIN dialog: "exit recipe" or "quit recipe" leaves the app
  RECIPE dialog: "exit recipe" or "quit recipe" requests and go back to the main dialog
*/

function handleFinishSessionRequest(intent, session, callback) {
    if (session.attributes.mode == "MAIN") {
      callback(session.attributes,
        buildSpeechletResponseWithoutCard("Good bye!", true));
    } else {
      getWelcomeResponse(callback);
    }
}

/*
  "exit" or "quit"
  Note: Cannot override sessionEndedRequest, so changed utterances
  to handle exit and quit in the recipe dialog
*/

function onSessionEnded(sessionEndedRequest, session) {
  console.log("onSessionEnded requestId=" + sessionEndedRequest.requestId
      + ", sessionId=" + session.sessionId);
}

// ------- Helper functions to build responses -------


function buildSpeechletResponse(title, output, shouldEndSession) {
    return {
        outputSpeech: {
            type: "PlainText",
            text: output
        },
        card: {
            type: "Simple",
            title: title,
            content: output
        },
        shouldEndSession: shouldEndSession
    };
}

function buildSpeechletResponseWithoutCard(output, shouldEndSession) {
    return {
        outputSpeech: {
            type: "PlainText",
            text: output
        },
        shouldEndSession: shouldEndSession
    };
}

function buildResponse(sessionAttributes, speechletResponse) {
    return {
        version: "1.0",
        sessionAttributes: sessionAttributes,
        response: speechletResponse
    };
}
