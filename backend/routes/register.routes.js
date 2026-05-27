const express = require("express");
const router = express.Router();

const auth = require("../controllers/auth.controller");

/* =========================
   SEND OTP
========================= */

router.post("/send-otp", (req,res,next)=>{

 if(!req.body.email){
   return res.status(400).json({message:"Email is required"});
 }

 next();

}, auth.sendOTP);


/* =========================
   VERIFY OTP
========================= */

router.post("/verify-otp", (req,res,next)=>{

 const {email,otp} = req.body;

 if(!email || !otp){
   return res.status(400).json({message:"Email and OTP required"});
 }

 next();

}, auth.verifyOTP);


/* =========================
   REGISTER
========================= */

router.post("/register", (req,res,next)=>{

 const {first_name,last_name,mobile,email,password,role} = req.body;

 if(!first_name || !last_name || !mobile || !email || !password || !role){
   return res.status(400).json({message:"All fields are mandatory"});
 }

 if(role !== "care_seeker" && role !== "care_taker"){
   return res.status(400).json({message:"Invalid role"});
 }

 next();

}, auth.register);


/* =========================
   LOGIN
========================= */

router.post("/login", (req,res,next)=>{

 const {email,password} = req.body;

 if(!email || !password){
   return res.status(400).json({message:"Email and password required"});
 }

 next();

}, auth.login);


module.exports = router;