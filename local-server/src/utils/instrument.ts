import { init } from "@sentry/node"

if (process.env.NODE_ENV === "production") {
	init({
		dsn: "https://8d55e1932aa9de6158f7990977a6f47a@o4509381911576576.ingest.us.sentry.io/4509964777160704",
		sendDefaultPii: false,
	})
}
