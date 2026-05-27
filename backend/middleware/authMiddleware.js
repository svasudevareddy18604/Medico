const jwt = require("jsonwebtoken");

const authMiddleware = (req, res, next) => {
  try {
    const header = req.headers.authorization;

    if (!header) {
      return res.status(401).json({
        success: false,
        message: "No token provided",
      });
    }

    // Format: Bearer TOKEN
    const token = header.split(" ")[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Invalid token format",
      });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // ✅ attach user to request
    req.user = decoded;

    next();

  } catch (err) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized",
    });
  }
};

module.exports = authMiddleware;