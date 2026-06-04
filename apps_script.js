/**
 * MoneyMate AI - Google Apps Script Backend API
 * 
 * Instructions:
 * 1. Open your Google Sheet.
 * 2. Click Extensions > Apps Script.
 * 3. Delete any code in the editor and paste this code.
 * 4. Click Deploy > New Deployment.
 * 5. Select type: Web App.
 * 6. Set Description: "MoneyMate API".
 * 7. Set Execute as: "Me" (your email).
 * 8. Set Who has access: "Anyone".
 * 9. Click Deploy, authorize permissions, and copy the Web App URL.
 */

var SCHEMAS = {
  "User Settings": ["userId", "email", "pin", "userName", "currency", "emergencyThreshold", "createdAt"],
  "Expenses": ["id", "userId", "amount", "category", "note", "date", "paymentMethod", "needOrWant"],
  "Income": ["id", "userId", "amount", "source", "date", "note"],
  "Borrowed": ["id", "userId", "personName", "amount", "borrowDate", "dueDate", "status", "ledger"],
  "Receivables": ["id", "userId", "personName", "amount", "date", "reminderStatus", "status", "ledger"],
  "Goals": ["id", "userId", "goalName", "targetAmount", "currentSavedAmount", "deadline"],
  "Budget": ["userId", "monthlyIncome", "needsBudget", "wantsBudget", "savingsBudget", "dailyLimit"],
  "Notifications": ["id", "userId", "title", "message", "timestamp", "isRead"]
};

/**
 * Handle GET requests (health check/status info)
 */
function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    message: "MoneyMate AI Apps Script API is running. Please use POST requests for operations."
  })).setMimeType(ContentService.MimeType.JSON);
}

/**
 * Handle POST requests (main API routing)
 */
function doPost(e) {
  var lock;
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error("Empty request body");
    }

    var requestData = JSON.parse(e.postData.contents);
    var action = requestData.action;
    var payload = requestData.payload || {};

    var writeActions = ['signUp', 'syncData', 'updateUserSettings'];
    if (writeActions.indexOf(action) !== -1) {
      lock = LockService.getScriptLock();
      lock.waitLock(30000); // Wait up to 30 seconds for lock
    }

    // Auto-initialize sheets/tabs if missing
    initSpreadsheet();

    var response;
    switch (action) {
      case 'signUp':
        response = signUp(payload);
        break;
      case 'login':
        response = login(payload);
        break;
      case 'getDashboardData':
        response = getDashboardData(payload);
        break;
      case 'syncData':
        response = syncData(payload);
        break;
      case 'updateUserSettings':
        response = updateUserSettings(payload);
        break;
      default:
        throw new Error('Unsupported action: ' + action);
    }

    return ContentService.createTextOutput(JSON.stringify({ success: true, data: response }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (error) {
    return ContentService.createTextOutput(JSON.stringify({ success: false, error: error.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    if (lock) {
      lock.releaseLock();
    }
  }
}

/**
 * Auto-initializes spreadsheet tabs and formatting
 */
function initSpreadsheet() {
  var cache = CacheService.getScriptCache();
  var isInit = cache.get("sheets_initialized");
  if (isInit === "true") {
    return;
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  for (var sheetName in SCHEMAS) {
    var sheet = ss.getSheetByName(sheetName);
    var expectedHeaders = SCHEMAS[sheetName];
    if (!sheet) {
      sheet = ss.insertSheet(sheetName);
      sheet.appendRow(expectedHeaders);
      // Apply clean header formatting
      var headerRange = sheet.getRange(1, 1, 1, expectedHeaders.length);
      headerRange.setFontWeight("bold");
      headerRange.setBackground("#E0F2F1"); // Pastel Teal background
      headerRange.setFontColor("#004D40");
      sheet.setFrozenRows(1);
    } else {
      var data = sheet.getDataRange().getValues();
      var currentHeaders = data[0] || [];

      // If the first header doesn't match expected first header, it's legacy/corrupted
      if (currentHeaders.length === 0 || currentHeaders[0] !== expectedHeaders[0]) {
        sheet.clear(); // Clear everything
        sheet.appendRow(expectedHeaders);
        var headerRange = sheet.getRange(1, 1, 1, expectedHeaders.length);
        headerRange.setFontWeight("bold");
        headerRange.setBackground("#E0F2F1");
        headerRange.setFontColor("#004D40");
        sheet.setFrozenRows(1);
      } else {
        // Self-migration: scan and append missing columns
        var missingHeaders = [];
        for (var k = 0; k < expectedHeaders.length; k++) {
          if (currentHeaders.indexOf(expectedHeaders[k]) === -1) {
            missingHeaders.push(expectedHeaders[k]);
          }
        }
        if (missingHeaders.length > 0) {
          var lastCol = sheet.getLastColumn();
          var range = sheet.getRange(1, lastCol + 1, 1, missingHeaders.length);
          range.setValues([missingHeaders]);
          range.setFontWeight("bold");
          range.setBackground("#E0F2F1");
          range.setFontColor("#004D40");
        }
      }
    }
  }

  // Cache database structure initialization status for 6 hours
  cache.put("sheets_initialized", "true", 21600);
}

/**
 * Register a new user
 */
function signUp(payload) {
  var email = (payload.email || "").trim().toLowerCase();
  var pin = (payload.pin || "").trim();
  var userName = (payload.userName || "").trim();

  if (!email || !pin || !userName) {
    throw new Error("Missing required fields: email, pin, userName");
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("User Settings");
  var data = sheet.getDataRange().getValues();

  // Check for existing email
  for (var i = 1; i < data.length; i++) {
    if (data[i][1].toString().toLowerCase() === email) {
      throw new Error("Email already registered");
    }
  }

  var userId = Utilities.getUuid();
  var createdAt = new Date().toISOString();
  var currency = "₹";
  var emergencyThreshold = 1000;

  // Append new user row
  sheet.appendRow([userId, email, pin, userName, currency, emergencyThreshold, createdAt]);

  // Initialize default budget row
  var budgetSheet = ss.getSheetByName("Budget");
  budgetSheet.appendRow([userId, 0, 0, 0, 0, 0]);

  return {
    userId: userId,
    email: email,
    userName: userName,
    currency: currency,
    emergencyThreshold: emergencyThreshold,
    budget: { monthlyIncome: 0, needsBudget: 0, wantsBudget: 0, savingsBudget: 0, dailyLimit: 0 }
  };
}

/**
 * Login user and verify credentials
 */
function login(payload) {
  var email = (payload.email || "").trim().toLowerCase();
  var pin = (payload.pin || "").trim();

  if (!email || !pin) {
    throw new Error("Missing email or PIN");
  }

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("User Settings");
  var data = sheet.getDataRange().getValues();

  for (var i = 1; i < data.length; i++) {
    if (data[i][1].toString().toLowerCase() === email) {
      if (data[i][2].toString() === pin) {
        var user = {
          userId: data[i][0],
          email: data[i][1],
          userName: data[i][3],
          currency: data[i][4],
          emergencyThreshold: Number(data[i][5]) || 1000
        };

        // Fetch user budget
        var budgetSheet = ss.getSheetByName("Budget");
        var budgetData = budgetSheet.getDataRange().getValues();
        var budget = { monthlyIncome: 0, needsBudget: 0, wantsBudget: 0, savingsBudget: 0, dailyLimit: 0 };
        for (var j = 1; j < budgetData.length; j++) {
          if (budgetData[j][0] === user.userId) {
            budget = {
              monthlyIncome: Number(budgetData[j][1]) || 0,
              needsBudget: Number(budgetData[j][2]) || 0,
              wantsBudget: Number(budgetData[j][3]) || 0,
              savingsBudget: Number(budgetData[j][4]) || 0,
              dailyLimit: Number(budgetData[j][5]) || 0
            };
            break;
          }
        }
        user.budget = budget;
        return user;
      } else {
        throw new Error("Incorrect PIN");
      }
    }
  }

  throw new Error("Email not found");
}

/**
 * Update general user settings
 */
function updateUserSettings(payload) {
  var userId = payload.userId;
  if (!userId) throw new Error("Missing userId");

  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getSheetByName("User Settings");
  var data = sheet.getDataRange().getValues();

  var userRowIndex = -1;
  for (var i = 1; i < data.length; i++) {
    if (data[i][0] === userId) {
      userRowIndex = i + 1;
      break;
    }
  }

  if (userRowIndex === -1) {
    var email = payload.email || "user@moneymate.ai";
    var pin = payload.pin || "1234";
    var userName = payload.userName || "User";
    var currency = payload.currency || "₹";
    var emergencyThreshold = Number(payload.emergencyThreshold) || 1000;
    var createdAt = new Date().toISOString();

    sheet.appendRow([userId, email, pin, userName, currency, emergencyThreshold, createdAt]);
  } else {
    // Set values if provided
    if (payload.userName !== undefined) sheet.getRange(userRowIndex, 4).setValue(payload.userName);
    if (payload.pin !== undefined) sheet.getRange(userRowIndex, 3).setValue(payload.pin);
    if (payload.currency !== undefined) sheet.getRange(userRowIndex, 5).setValue(payload.currency);
    if (payload.emergencyThreshold !== undefined) sheet.getRange(userRowIndex, 6).setValue(Number(payload.emergencyThreshold));
  }

  return { status: "success" };
}

/**
 * Fetch all consolidated metrics and records for the user
 */
function getDashboardData(payload) {
  var userId = payload.userId;
  if (!userId) throw new Error("Missing userId");

  var ss = SpreadsheetApp.getActiveSpreadsheet();

  var expenses = getRowsForUser(ss, "Expenses", userId);
  var income = getRowsForUser(ss, "Income", userId);
  var borrowed = getRowsForUser(ss, "Borrowed", userId);
  var receivables = getRowsForUser(ss, "Receivables", userId);
  var goals = getRowsForUser(ss, "Goals", userId);
  var notifications = getRowsForUser(ss, "Notifications", userId);

  // Calculate summary metrics
  var totalIncome = 0;
  income.forEach(function (r) { totalIncome += Number(r.amount) || 0; });

  var totalExpenses = 0;
  expenses.forEach(function (r) { totalExpenses += Number(r.amount) || 0; });

  var currentBalance = totalIncome - totalExpenses;

  var pendingBorrowed = 0;
  borrowed.forEach(function (r) {
    if (r.status === "Pending") {
      pendingBorrowed += Number(r.amount) || 0;
    }
  });

  var pendingReceivables = 0;
  receivables.forEach(function (r) {
    if (r.status === "Pending") {
      pendingReceivables += Number(r.amount) || 0;
    }
  });

  var totalSavings = 0;
  goals.forEach(function (r) {
    totalSavings += Number(r.currentSavedAmount) || 0;
  });

  // Calculate daily budget limit and daily remaining
  var budgetList = getRowsForUser(ss, "Budget", userId);
  var dailyLimit = 0;
  var budget = { monthlyIncome: 0, needsBudget: 0, wantsBudget: 0, savingsBudget: 0, dailyLimit: 0 };
  if (budgetList.length > 0) {
    dailyLimit = Number(budgetList[0].dailyLimit) || 0;
    budget = {
      monthlyIncome: Number(budgetList[0].monthlyIncome) || 0,
      needsBudget: Number(budgetList[0].needsBudget) || 0,
      wantsBudget: Number(budgetList[0].wantsBudget) || 0,
      savingsBudget: Number(budgetList[0].savingsBudget) || 0,
      dailyLimit: dailyLimit
    };
  }

  // Filter today's expenses to compute remaining daily budget
  var todayStr = getLocalDateString();
  var todayExpenses = 0;
  expenses.forEach(function (r) {
    var dateStr = parseDateString(r.date);
    if (dateStr === todayStr) {
      todayExpenses += Number(r.amount) || 0;
    }
  });

  var dailyBudgetRemaining = dailyLimit - todayExpenses;

  return {
    summary: {
      currentBalance: currentBalance,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalSavings: totalSavings,
      pendingBorrowed: pendingBorrowed,
      pendingReceivables: pendingReceivables,
      dailyLimit: dailyLimit,
      dailyBudgetRemaining: dailyBudgetRemaining
    },
    budget: budget,
    expenses: expenses,
    income: income,
    borrowed: borrowed,
    receivables: receivables,
    goals: goals,
    notifications: notifications
  };
}

/**
 * Unified endpoint for bulk synchronizing offline edits
 */
function syncData(payload) {
  var userId = payload.userId;
  if (!userId) throw new Error("Missing userId");

  var ss = SpreadsheetApp.getActiveSpreadsheet();

  // Batch sync each table
  if (payload.expenses) syncTable(ss, "Expenses", userId, payload.expenses);
  if (payload.income) syncTable(ss, "Income", userId, payload.income);
  if (payload.borrowed) syncTable(ss, "Borrowed", userId, payload.borrowed);
  if (payload.receivables) syncTable(ss, "Receivables", userId, payload.receivables);
  if (payload.goals) syncTable(ss, "Goals", userId, payload.goals);
  if (payload.notifications) syncTable(ss, "Notifications", userId, payload.notifications);

  // Sync budget
  if (payload.budget) {
    var budgetSheet = ss.getSheetByName("Budget");
    var budgetData = budgetSheet.getDataRange().getValues();
    var foundIndex = -1;
    for (var i = 1; i < budgetData.length; i++) {
      if (budgetData[i][0] === userId) {
        foundIndex = i;
        break;
      }
    }

    var b = payload.budget;
    var rowValues = [userId, Number(b.monthlyIncome) || 0, Number(b.needsBudget) || 0, Number(b.wantsBudget) || 0, Number(b.savingsBudget) || 0, Number(b.dailyLimit) || 0];
    if (foundIndex !== -1) {
      budgetData[foundIndex] = rowValues;
      budgetSheet.clearContents();
      budgetSheet.getRange(1, 1, budgetData.length, budgetData[0].length).setValues(budgetData);
    } else {
      budgetData.push(rowValues);
      budgetSheet.clearContents();
      budgetSheet.getRange(1, 1, budgetData.length, budgetData[0].length).setValues(budgetData);
    }
  }

  return { status: "success", syncedAt: new Date().toISOString() };
}

/**
 * Helper to sync a table for a user with upserts and deletions
 */
function syncTable(ss, sheetName, userId, items) {
  if (!items || items.length === 0) return;

  var sheet = ss.getSheetByName(sheetName);
  var range = sheet.getDataRange();
  var data = range.getValues();
  var headers = data[0];

  var idIndex = headers.indexOf("id");
  var userIdIndex = headers.indexOf("userId");

  if (idIndex === -1 || userIdIndex === -1) {
    throw new Error("Sheet " + sheetName + " must contain 'id' and 'userId' columns");
  }

  // Build a lookup map of item ID -> row index in the `data` array (0-based)
  var rowIndices = {};
  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (row[userIdIndex] === userId) {
      rowIndices[row[idIndex]] = i;
    }
  }

  var modified = false;

  items.forEach(function (item) {
    var itemId = item.id;
    if (!itemId) return;

    var action = item._action || "upsert";
    var rowIndex = rowIndices[itemId];

    if (action === "delete") {
      if (rowIndex !== undefined) {
        // Splice from data array
        data.splice(rowIndex, 1);
        modified = true;

        // Correct remaining cached row indices
        for (var key in rowIndices) {
          if (rowIndices[key] > rowIndex) {
            rowIndices[key]--;
          }
        }
        delete rowIndices[itemId];
      }
    } else {
      // Build row data array matching the headers
      var rowValues = [];
      headers.forEach(function (header) {
        if (header === "userId") {
          rowValues.push(userId);
        } else if (header === "date" || header === "borrowDate" || header === "dueDate" || header === "deadline" || header === "timestamp" || header === "createdAt") {
          rowValues.push(item[header] ? new Date(item[header]) : "");
        } else if (header === "isRead") {
          rowValues.push(item[header] === true || item[header] === "true");
        } else {
          rowValues.push(item[header] !== undefined ? item[header] : "");
        }
      });

      if (rowIndex !== undefined) {
        data[rowIndex] = rowValues;
        modified = true;
      } else {
        data.push(rowValues);
        rowIndices[itemId] = data.length - 1;
        modified = true;
      }
    }
  });

  if (modified) {
    sheet.clearContents();
    sheet.getRange(1, 1, data.length, headers.length).setValues(data);
  }
}

/**
 * General helper to get all records for a user
 */
function getRowsForUser(ss, sheetName, userId) {
  var sheet = ss.getSheetByName(sheetName);
  var data = sheet.getDataRange().getValues();
  var headers = data[0];
  var userRows = [];

  var userIdIndex = (sheetName === "User Settings" || sheetName === "Budget") ? 0 : 1;

  for (var i = 1; i < data.length; i++) {
    var row = data[i];
    if (row[userIdIndex] === userId) {
      var obj = {};
      for (var j = 0; j < headers.length; j++) {
        var val = row[j];
        // Convert date/timestamp objects to ISO string representation for easier client-side parsing
        if (val instanceof Date) {
          obj[headers[j]] = val.toISOString();
        } else {
          obj[headers[j]] = val;
        }
      }
      userRows.push(obj);
    }
  }
  return userRows;
}

/**
 * Formats a Date object or string as YYYY-MM-DD
 */
function parseDateString(dateVal) {
  if (!dateVal) return "";
  var d = (dateVal instanceof Date) ? dateVal : new Date(dateVal);
  if (isNaN(d.getTime())) return "";

  var month = '' + (d.getMonth() + 1);
  var day = '' + d.getDate();
  var year = d.getFullYear();

  if (month.length < 2) month = '0' + month;
  if (day.length < 2) day = '0' + day;

  return [year, month, day].join('-');
}

/**
 * Returns today's date in local time zone as YYYY-MM-DD
 */
function getLocalDateString() {
  var tz = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone();
  return Utilities.formatDate(new Date(), tz, "yyyy-MM-dd");
}
