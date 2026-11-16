package com.example.apk_idk

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import android.util.Log
import org.json.JSONObject

/** Independent local event log. Never reset the main Flutter database. */
class ReminderHistoryStore(context: Context) : SQLiteOpenHelper(context, "reminder_history.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE events (id INTEGER PRIMARY KEY AUTOINCREMENT, time_ms INTEGER NOT NULL, habit_id INTEGER NOT NULL, title TEXT NOT NULL, event TEXT NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { }
    fun append(record: JSONObject, event: String) {
        writableDatabase.execSQL("INSERT INTO events (time_ms, habit_id, title, event) VALUES (?, ?, ?, ?)",
            arrayOf(System.currentTimeMillis(), record.optInt("habit"), record.optString("title", "Alarm habit"), event))
    }
    fun latest(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        readableDatabase.rawQuery("SELECT id, time_ms, habit_id, title, event FROM events ORDER BY id DESC LIMIT 200", null).use { c ->
            while (c.moveToNext()) result.add(mapOf("id" to c.getLong(0), "time" to c.getLong(1), "habit" to c.getInt(2), "title" to c.getString(3), "event" to c.getString(4)))
        }
        return result
    }
    companion object {
        fun log(context: Context, record: JSONObject, event: String) {
            // Logging failure must never prevent alarm controls from functioning.
            try { ReminderHistoryStore(context).use { it.append(record, event) } }
            catch (e: Exception) { Log.e("ReminderHistory", "Could not record alarm event", e) }
        }
    }
}
