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
                  dishes += i.RecipeName + ', ';
              }
              context.done(
                  getSearchTerms(dishes,
                      function callback(sessionAttributes, speechletResponse) {
                          context.succeed(buildResponse(sessionAttributes, speechletResponse));
                  })
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

        else if (event.request.intent.name === "searchRecipeIntent")  {
          var dishIngredients = [];
          var dishDirections = [];
          dynamodb.query({
              TableName : "Recipes",
              KeyConditionExpression: "#rec = :dish",
              ExpressionAttributeNames:{
                "#rec": "RecipeName"
              },
              ExpressionAttributeValues: {
                ":dish": event.request.intent.slots.Recipe.value // GET INTENT SLOT
              }
          }, function(err, data) {
              if (err) {
                  context.done(null, "Error");
              } else if (data.Items[0] === undefined) {
                  noRecipeFoundError(event.request.intent.slots.Recipe.value,
                      function callback(sessionAttributes, speechletResponse) {
                          context.succeed(buildResponse(sessionAttributes, speechletResponse));
                     });
              } else {
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
              }
          });

        } else {
          handleRecipeIntent(
              event.session.attributes.ingredients,
              event.session.attributes.directions,
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

/*
  DynamoDB Query Returns Error
*/

function noRecipeFoundError(recipeName, callback) {
    var sessionAttributes = {},
        speechOutput = "There is no recipe found for " + recipeName,
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
  if (intent.name === "searchRecipeIntent") {
    var speechOutput = "The first ingredient is " + ingredients[0];
    var sessionAttributes = {
        "speechOutput": speechOutput,
        "mode": "INGREDIENTS",
        "curr": 0,
        "ingredients": ingredients,
        "directions": directions
    };

    callback(sessionAttributes,
        buildSpeechletResponse(CARD_TITLE, speechOutput, false));

  /*
    Retrieve session attributes
  */
  } else {
      var curr = session.attributes.curr,
          mode = session.attributes.mode,
          ingredientsLen = ingredients.length,
          directionsLen = directions.length;

    /*
    Called when:  Restart current dialog
    */
    if (intent.name === "handleRestartIntent") {

        var speechOutput = "";

        if (mode === "INGREDIENTS" || (mode === "DIRECTIONS" && curr == 0)) {
          speechOutput = "The first ingredient is " + ingredients[0];
          mode = "INGREDIENTS";
        } else if (mode === "DIRECTIONS") {
          speechOutput = "First, " + directions[0];
          mode = "DIRECTIONS";
        }

        var sessionAttributes = {
              "speechOutput": speechOutput,
              "mode": mode,
              "curr": 0,
              "ingredients": ingredients,
              "directions": directions
          };

          callback(sessionAttributes,
              buildSpeechletResponse(CARD_TITLE, speechOutput, false));

    /*
    Called when:  Moved to Ingredients dialog
    */
    } else if (intent.name === "handleIngredientsIntent") {

        var speechOutput = "The first ingredient is " + ingredients[0];
        var sessionAttributes = {
              "speechOutput": speechOutput,
              "mode": "INGREDIENTS",
              "curr": 0,
              "ingredients": ingredients,
              "directions": directions
          };

          callback(sessionAttributes,
              buildSpeechletResponse(CARD_TITLE, speechOutput, false));

    /*
    Called when:  Moved to Recipe dialog
    */
    } else if (intent.name === "handleRecipeIntent") {

        var speechOutput = "First, " + directions[0];
        var sessionAttributes = {
              "speechOutput": speechOutput,
              "mode": "DIRECTIONS",
              "curr": 0,
              "ingredients": ingredients,
              "directions": directions
          };

          callback(sessionAttributes,
              buildSpeechletResponse(CARD_TITLE, speechOutput, false));

    /*
      Called when:  1. increment/decrement Ingredients 
                    2. increment/decrement Directions 
    */
    } else if (intent.name === "incrementIntent") {
    
      var order = intent.slots.Order.value,
          incrementType = intent.slots.IncrementType.value,
          speechOutput = '';
        console.log(order);
        console.log(incrementType);
      /* Increment or decrement accordingly */
      if (order === 'next' || order === 'Next') { curr++; }
      if (order === 'last' || order === 'Last') { curr--; }
        
      if (mode === "INGREDIENTS" && incrementType === 'Ingredient' || incrementType === 'ingredient') {
        
        /* Reached end of ingredients, move to DIRECTIONS mode */
        if (curr >= ingredientsLen) {
          mode = "DIRECTIONS";
          speechOutput = "Reached end of ingredients. First step, " + directions[0];
          curr = 0;

        /* No more 'last' ingredient */
        } else if (curr < 0) {
          speechOutput = "There is no last ingredient.";
          curr = -1;
        
        /* Say next or last ingredient */
        } else {
          speechOutput = ingredients[curr];
        }

      } else if (mode === "DIRECTIONS" && incrementType === 'Step' || incrementType === 'step') {

        /* Reached end of directions, complete. */
        if (curr >= directionsLen) {
          speechOutput = "Reached end of directions. Recipe is complete.";
          curr = directionsLen;

        /* No more 'last' step */
        } else if (curr < 0) {
          speechOutput = "There is no last step.";
          curr = -1;
        
        /* Say next or last ingredient */
        } else {
          speechOutput = directions[curr];
        }

      } else {
        if (mode === "DIRECTIONS" && curr == -1) {
          mode = "INGREDIENTS";
          curr = ingredientsLen - 1;
          speechOutput = "Last ingredient is " + ingredients[curr];
        } else {
          speechOutput = "Unable to understand your request.";
          if (order === 'next' || order === 'Next') { curr--; }
          if (order === 'last' || order === 'Last') { curr++; }
        }
      }

      var sessionAttributes = {
          "speechOutput": speechOutput,
          "mode": mode,
          "curr": curr,
          "ingredients": ingredients,
          "directions": directions
      };

      callback(sessionAttributes,
              buildSpeechletResponse(CARD_TITLE, speechOutput, false));

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
    if (session.attributes.mode === "MAIN") {
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
