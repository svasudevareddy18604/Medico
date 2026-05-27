const mysql = require("mysql2/promise");

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,

  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 10000,

  ssl: {
    rejectUnauthorized: false
  }
});

/* TEST CONNECTION ON START */
(async () => {
  try {
    const connection = await pool.getConnection();
    console.log("✅ MySQL connected successfully");
    connection.release();
  } catch (err) {
    console.error("❌ MySQL connection failed:", err);
  }
})();

/* KEEP CONNECTION ALIVE */
setInterval(async () => {
  try {
    await pool.query("SELECT 1");
  } catch (err) {
    console.error("DB keepalive error:", err);
  }
}, 60000);

module.exports = pool;