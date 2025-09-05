import Sentry from "@sentry/node"

if (process.env.NODE_ENV === "production") {
	Sentry.init({
		dsn: "https://8d55e1932aa9de6158f7990977a6f47a@o4509381911576576.ingest.us.sentry.io/4509964777160704",
		// Setting this option to true will send default PII data to Sentry.
		// For example, automatic IP address collection on events
		sendDefaultPii: true,
	})
}
