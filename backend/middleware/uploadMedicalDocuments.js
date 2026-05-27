const multer = require("multer");

const path = require("path");

const fs = require("fs");

/* =========================================
   CREATE FOLDER
========================================= */

const uploadPath = path.join(
  __dirname,
  "../uploads/medical-documents"
);

if (!fs.existsSync(uploadPath)) {

  fs.mkdirSync(uploadPath, {
    recursive: true,
  });
}

/* =========================================
   STORAGE
========================================= */

const storage = multer.diskStorage({

  destination: (req, file, cb) => {

    cb(null, uploadPath);
  },

  filename: (req, file, cb) => {

    const uniqueName =
      Date.now() +
      "-" +
      file.originalname.replace(
        /\s+/g,
        "-"
      );

    cb(null, uniqueName);
  },
});

/* =========================================
   FILE FILTER
========================================= */

const fileFilter = (
  req,
  file,
  cb
) => {

  console.log(
    "UPLOADED MIME TYPE:",
    file.mimetype
  );

  const allowedMimeTypes = [

    "image/jpeg",

    "image/jpg",

    "image/png",

    "image/webp",

    "image/heic",

    "image/heif",

    "image/avif",

    "application/octet-stream",

    "application/pdf",
  ];

  if (
    allowedMimeTypes.includes(
      file.mimetype
    )
  ) {

    cb(null, true);

  } else {

    console.log(
      "BLOCKED MIME TYPE:",
      file.mimetype
    );

    cb(
      new Error(
        "Only image and PDF files are allowed"
      ),
      false
    );
  }
};

/* =========================================
   MULTER
========================================= */

const uploadMedicalDocuments =
  multer({

    storage,

    fileFilter,

    limits: {

      fileSize:
        10 * 1024 * 1024,

      files: 5,
    },
  });

/* =========================================
   EXPORT
========================================= */

module.exports =
  uploadMedicalDocuments;