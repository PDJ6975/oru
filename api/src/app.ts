import express, { Request, Response } from "express";
import { httpLogger } from "./middleware/httpLogger.js";
import { userRoutes } from "./routes/user.routes.js";
import { errorHandler } from "./middleware/errorHandler.js";
import { habitRoutes } from "./routes/habit.routes.js";

const app = express();

app.use(httpLogger);
app.use(express.json());

app.use("/api/v1", userRoutes);
app.use("/api/v1", habitRoutes);
app.get("/", (req: Request, res: Response) => {
  res.send("Backend is running!");
});
app.use(errorHandler);

export default app;
