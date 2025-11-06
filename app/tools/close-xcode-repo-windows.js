#!/usr/bin/env osascript -l JavaScript

// Close Xcode windows that belong to a specific repository.
// Usage: REPO=/path/to/repo osascript -l JavaScript close-xcode-repo-windows.js

ObjC.import('Foundation');
ObjC.import('stdlib');

function canonicalizePath(p, isDir = false) {
	try {
		const url = $.NSURL.fileURLWithPathIsDirectory($(p), isDir);
		const std = url.URLByStandardizingPath;
		const res = std.URLByResolvingSymlinksInPath;
		let path = ObjC.unwrap(res.path);
		if (isDir && !path.endsWith('/')) path += '/';
		return path;
	} catch (e) {
		return p;
	}
}

function fileExists(p) {
	return $.NSFileManager.defaultManager.fileExistsAtPath($(p));
}

function isSwiftPackageRoot(p) {
	if (!p) return false;
	const url = $.NSURL.fileURLWithPath($(p));
	const dir = ObjC.unwrap(url.URLByDeletingLastPathComponent.path);
	return fileExists(dir + '/Package.swift') || fileExists(p + '/Package.swift');
}

function isRepoWindowPath(p, repoCanonLower) {
	if (!p) return false;
	const canon = canonicalizePath(p, false).toLowerCase();
	return canon.startsWith(repoCanonLower);
}

function isPrimaryContainer(p) {
	if (!p) return false;
	return p.endsWith('.xcworkspace') || p.endsWith('.xcodeproj') || isSwiftPackageRoot(p);
}

const repoRaw = ObjC.unwrap($.getenv('REPO'));
if (!repoRaw) throw new Error('REPO env var not set');

const repoCanon = canonicalizePath(repoRaw, true);
const repoCanonLower = repoCanon.toLowerCase();

const Xcode = Application('Xcode');
Xcode.includeStandardAdditions = true;

let closed = 0;
const wins = (() => {
	try {
		return Xcode.windows();
	} catch (e) {
		return [];
	}
})();

wins.forEach((w) => {
	const doc = (() => {
		try {
			return w.document();
		} catch (e) {
			return null;
		}
	})();

	if (!doc) return;

	const fileA = (() => {
		try {
			return doc.file();
		} catch (e) {
			return null;
		}
	})();

	const path = fileA ? String(fileA) : null;
	const underRepo = isRepoWindowPath(path, repoCanonLower);
	const isContainer = isPrimaryContainer(path);

	if (underRepo && isContainer) {
		try {
			w.close();
			closed++;
		} catch (e) {}
	}
});
