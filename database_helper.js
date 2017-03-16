'use strict';
module.change_code = 1;
var _ = require('lodash');
var CAKEBAKER_DATA_TABLE_NAME = 'Recipes';
var dynasty = require('dynasty')({});

function CakeBakerHelper() {}
var cakeBakerTable = function() {
  return dynasty.table(CAKEBAKER_DATA_TABLE_NAME);
};

// CakeBakerHelper.prototype.createCakeBakerTable = function() {
//   return dynasty.describe(CAKEBAKER_DATA_TABLE_NAME)
//     .catch(function(error) {
//       return dynasty.create(CAKEBAKER_DATA_TABLE_NAME, {
//         key_schema: {
//           hash: ['RecipeName', 'string']
//         }
//       });
//     });
// };

// CakeBakerHelper.prototype.storeCakeBakerData = function(userId, cakeBakerData) {
//   return cakeBakerTable().insert({
//     userId: userId,
//     data: cakeBakerData
//   }).catch(function(error) {
//     console.log(error);
//   });
// };

CakeBakerHelper.prototype.readCakeBakerData = function(recipeName) {
  return cakeBakerTable().find(recipeName)
    .then(function(result) {
      return result;
    })
    .catch(function(error) {
      console.log(error);
    });
};

CakeBakerHelper.prototype.readAllRecipes = function() {
  return cakeBakerTable().scan()
    .then(function(result) {
      return result;
    })
    .catch(function(error) {
      console.log(error);
    });
};

module.exports = CakeBakerHelper;
