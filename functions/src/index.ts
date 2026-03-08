import * as admin from "firebase-admin";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();

const ADMIN_EMAILS = new Set(["hello@studioleaf.kr"]);
const EXTERNAL_STORAGE_ACCOUNTS_PATH = "portalSettings/externalStorageAccounts";
const PROJECT_ARCHIVE_JOBS_PATH = "projectArchiveJobs";

const googleDriveClientId = defineSecret("GOOGLE_DRIVE_OAUTH_CLIENT_ID");
const googleDriveClientSecret = defineSecret("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET");
const googleDriveRefreshToken = defineSecret("GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN");
const googleDriveSharedDriveId = defineSecret("GOOGLE_DRIVE_SHARED_DRIVE_ID");
const googleDriveProjectHubRootFolderId = defineSecret("GOOGLE_DRIVE_PROJECT_HUB_ROOT_FOLDER_ID");

const dropboxAppKey = defineSecret("DROPBOX_APP_KEY");
const dropboxAppSecret = defineSecret("DROPBOX_APP_SECRET");
const dropboxRefreshToken = defineSecret("DROPBOX_REFRESH_TOKEN");

const DEFAULT_DROPBOX_ROOT_PATH = "/01_ProjectHub";
const DROPBOX_API_BASE = "https://api.dropboxapi.com/2";
const DROPBOX_CONTENT_API_BASE = "https://content.dropboxapi.com/2";

type ExternalStorageAccountStatus = {
  executionEmail?: string;
  accountLabel?: string;
  connectionState?: string;
  notes?: string;
  lastValidatedAt?: admin.firestore.Timestamp;
};

type ExternalStorageAccountsDocument = {
  googleDrive?: ExternalStorageAccountStatus;
  dropbox?: ExternalStorageAccountStatus;
  updatedAt?: admin.firestore.Timestamp;
  updatedByEmail?: string;
  updatedByName?: string;
};

type ArchiveStorageFolder = {
  id: string;
  title: string;
  provider: "googleDrive" | "dropbox";
  relativePath: string;
  keywords?: string[];
  allowedExtensions?: string[];
  sortOrder?: number;
  isRequired?: boolean;
  isVisible?: boolean;
};

type DriveFile = {
  id: string;
  name: string;
  mimeType?: string;
  webViewLink?: string;
  driveId?: string;
  parents?: string[];
  size?: string;
  modifiedTime?: string;
  iconLink?: string;
};

type GoogleDriveValidationResponse = {
  sharedDrive: {
    id: string;
    name: string;
  };
  rootFolder: {
    id: string;
    name: string;
    webViewLink: string;
    driveId?: string;
  };
};

type GoogleDriveProvisionResponse = {
  archiveId: string;
  yearFolder: {
    id: string;
    name: string;
    webViewLink: string;
  };
  projectFolder: {
    id: string;
    name: string;
    webViewLink: string;
  };
  createdFolders: Array<{
    id: string;
    name: string;
    webViewLink: string;
    relativePath: string;
  }>;
};

type GoogleDriveDeleteResponse = {
  archiveId: string;
  deletedFolderId: string;
};

type DropboxValidationResponse = {
  account: {
    accountId: string;
    email: string;
    name: string;
  };
  rootPath: string;
};

type DropboxProvisionResponse = {
  archiveId: string;
  projectRootPath: string;
  projectRootTitle: string;
  projectRootWebURL: string;
  createdFolders: Array<{
    path: string;
    name: string;
    webViewLink: string;
    relativePath: string;
  }>;
};

type DropboxDeleteResponse = {
  archiveId: string;
  deletedPath: string;
};

type DropboxFolderItem = {
  id: string;
  name: string;
  pathDisplay: string;
  pathLower: string;
  isFolder: boolean;
  webViewLink: string;
  sizeBytes?: number;
  modifiedAt?: string;
};

type DropboxFolderListingResponse = {
  archiveId: string;
  folderPath: string;
  folderTitle: string;
  relativePath: string;
  items: DropboxFolderItem[];
};

type DropboxUploadSession = {
  accessToken: string;
  uploadPath: string;
  folderPath: string;
  folderTitle: string;
  relativePath: string;
  webViewLink: string;
  pathRootHeader?: string;
};

type DropboxCurrentAccount = {
  account_id: string;
  name: {display_name: string};
  email: string;
  root_info?: {
    ".tag"?: string;
    root_namespace_id?: string;
    home_namespace_id?: string;
    home_path?: string;
  };
};

type DropboxMetadata = {
  ".tag": string;
  id: string;
  name: string;
  path_display?: string;
  path_lower?: string;
  client_modified?: string;
  server_modified?: string;
  size?: number;
};

type DropboxListFolderResponse = {
  entries: DropboxMetadata[];
};

type ProjectArchiveJobType =
  | "validateGoogleDriveAdmin"
  | "provisionGoogleDriveFolders"
  | "deleteGoogleDriveFolders"
  | "listGoogleDriveFolderContents"
  | "createGoogleDriveUploadSession"
  | "createDropboxUploadSession"
  | "validateDropboxAdmin"
  | "provisionDropboxFolders"
  | "deleteDropboxFolders"
  | "listDropboxFolderContents";

type ProjectArchiveJob = {
  type: ProjectArchiveJobType;
  archiveId?: string;
  year?: number;
  requestedById: string;
  requestedByEmail?: string;
  status: "queued" | "running" | "completed" | "failed";
  errorMessage?: string;
  result?: Record<string, unknown>;
  createdAt?: admin.firestore.Timestamp;
  updatedAt?: admin.firestore.Timestamp;
  completedAt?: admin.firestore.Timestamp;
};

type CallableAuth = {
  uid: string;
  token: Record<string, unknown>;
} | null | undefined;

function requireAuth(auth: CallableAuth) {
  if (!auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return auth;
}

function requireAdmin(auth: {uid: string; token: Record<string, unknown>}) {
  const email = String(auth.token.email ?? "").toLowerCase();
  if (!ADMIN_EMAILS.has(email)) {
    throw new HttpsError("permission-denied", "관리자만 접근할 수 있습니다.");
  }
  return email;
}

function asExternalStorageDocument(
  snapshot: admin.firestore.DocumentSnapshot<admin.firestore.DocumentData>
): ExternalStorageAccountsDocument {
  return (snapshot.data() ?? {}) as ExternalStorageAccountsDocument;
}

function mergeProviderStatus(
  current: ExternalStorageAccountStatus | undefined,
  patch: Partial<ExternalStorageAccountStatus>
): ExternalStorageAccountStatus {
  return {
    executionEmail: current?.executionEmail ?? "pd@studioleaf.kr",
    accountLabel: current?.accountLabel ?? "",
    connectionState: current?.connectionState ?? "notConfigured",
    notes: current?.notes ?? "",
    lastValidatedAt: current?.lastValidatedAt,
    ...patch,
  };
}

function sanitizeFolderName(value: string) {
  return value
    .replace(/[\\/:*?"<>|]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeDropboxPath(value: string) {
  const trimmed = value.trim();
  if (!trimmed) {
    return "/";
  }

  const segments = trimmed
    .split("/")
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);

  return `/${segments.join("/")}`;
}

function joinDropboxPath(basePath: string, relativePath: string) {
  const normalizedBase = normalizeDropboxPath(basePath);
  const normalizedRelative = relativePath
    .split("/")
    .map((segment) => sanitizeFolderName(segment))
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0)
    .join("/");

  if (!normalizedRelative) {
    return normalizedBase;
  }

  if (normalizedBase === "/") {
    return `/${normalizedRelative}`;
  }

  return `${normalizedBase}/${normalizedRelative}`;
}

function isPathUnderDropboxRoot(rootPath: string, targetPath: string) {
  const normalizedRoot = normalizeDropboxPath(rootPath);
  const normalizedTarget = normalizeDropboxPath(targetPath);
  if (normalizedRoot === "/") {
    return true;
  }

  return normalizedTarget === normalizedRoot || normalizedTarget.startsWith(`${normalizedRoot}/`);
}

function buildDropboxWebURL(path: string) {
  const normalized = normalizeDropboxPath(path).replace(/^\//, "");
  if (!normalized) {
    return "https://www.dropbox.com/home";
  }
  const encoded = normalized
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
  return `https://www.dropbox.com/home/${encoded}`;
}

function normalizeUploadMetadataText(value: unknown) {
  return String(value ?? "").trim();
}

function normalizeUploadKeywords(value: unknown) {
  if (Array.isArray(value)) {
    const chunks = value
      .flatMap((item) => (typeof item === "string" ? item.split(/[,;\n]+/g) : []))
      .map((token) => token.trim())
      .filter(Boolean);
    const uniq = new Set<string>();
    for (const token of chunks) {
      uniq.add(token);
    }
    return Array.from(uniq);
  }

  const raw = typeof value === "string" ? value : "";
  if (!raw) {
    return [];
  }

  const chunks = raw.split(/[,;\n]+/g).map((token) => token.trim()).filter(Boolean);
  const uniq = new Set<string>();
  for (const token of chunks) {
    uniq.add(token);
  }
  return Array.from(uniq);
}

function escapeDriveQueryValue(value: string) {
  return value.replace(/\\/g, "\\\\").replace(/'/g, "\\'");
}

async function getGoogleDriveAccessToken() {
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      client_id: googleDriveClientId.value(),
      client_secret: googleDriveClientSecret.value(),
      refresh_token: googleDriveRefreshToken.value(),
      grant_type: "refresh_token",
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    logger.error("Google OAuth token refresh failed", {status: response.status, text});
    throw new HttpsError("internal", "Google Drive access token을 갱신하지 못했습니다.");
  }

  const payload = await response.json() as {access_token?: string};
  if (!payload.access_token) {
    throw new HttpsError("internal", "Google Drive access token 응답이 비어 있습니다.");
  }

  return payload.access_token;
}

async function getDropboxAccessToken() {
  const response = await fetch("https://api.dropboxapi.com/oauth2/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: dropboxRefreshToken.value(),
      client_id: dropboxAppKey.value(),
      client_secret: dropboxAppSecret.value(),
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    logger.error("Dropbox OAuth token refresh failed", {status: response.status, text});
    let friendlyMessage = "Dropbox access token을 갱신하지 못했습니다.";
    try {
      const payload = JSON.parse(text) as {
        error?: string;
        error_description?: string;
      };
      if (payload.error === "invalid_grant") {
        const description = String(payload.error_description ?? "").toLowerCase();
        if (description.includes("malformed")) {
          friendlyMessage = "Dropbox refresh token 형식이 잘못되었습니다. Secret Manager의 DROPBOX_REFRESH_TOKEN 값을 다시 저장해 주세요.";
        } else {
          friendlyMessage = "Dropbox refresh token이 만료되었거나 유효하지 않습니다. pd@studioleaf.kr 계정으로 refresh token을 다시 발급해 주세요.";
        }
      } else if (payload.error === "invalid_client") {
        friendlyMessage = "Dropbox 앱 키 또는 앱 시크릿이 올바르지 않습니다. Secret Manager의 DROPBOX_APP_KEY, DROPBOX_APP_SECRET 값을 확인해 주세요.";
      }
    } catch (_error) {
      // Keep the generic message when the OAuth error body is not JSON.
    }
    throw new HttpsError("internal", friendlyMessage);
  }

  const payload = await response.json() as {access_token?: string};
  if (!payload.access_token) {
    throw new HttpsError("internal", "Dropbox access token 응답이 비어 있습니다.");
  }

  return payload.access_token;
}

async function dropboxRequest<T>(
  accessToken: string,
  endpoint: string,
  init?: RequestInit,
  pathRootHeader?: string
): Promise<T> {
  const response = await fetch(`${DROPBOX_API_BASE}/${endpoint}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(pathRootHeader ? {"Dropbox-API-Path-Root": pathRootHeader} : {}),
      ...(init?.headers ?? {}),
    },
  });

  if (!response.ok) {
    const text = await response.text();
    let summary = "";
    try {
      const parsed = JSON.parse(text) as {error_summary?: string; error?: {error_summary?: string}};
      summary = parsed.error_summary ?? parsed.error?.error_summary ?? "";
    } catch (_error) {
      // ignore
    }
    logger.error("Dropbox API request failed", {
      endpoint,
      status: response.status,
      text,
    });
    const message = summary
      ? `Dropbox API 요청에 실패했습니다. ${summary}`
      : "Dropbox API 요청에 실패했습니다.";
    throw new HttpsError("internal", message);
  }

  return await response.json() as T;
}

function makeDropboxPathRootHeader(account: DropboxCurrentAccount) {
  const rootNamespaceId = String(account.root_info?.root_namespace_id ?? "").trim();
  if (!rootNamespaceId) {
    return undefined;
  }

  return JSON.stringify({
    ".tag": "root",
    root: rootNamespaceId,
  });
}

async function getDropboxCurrentAccount(accessToken: string) {
  return await dropboxRequest<DropboxCurrentAccount>(accessToken, "users/get_current_account", {
    method: "POST",
    body: "null",
  });
}

async function getDropboxMetadata(
  accessToken: string,
  path: string,
  pathRootHeader?: string
): Promise<DropboxMetadata | null> {
  const normalizedPath = normalizeDropboxPath(path);
  if (normalizedPath === "/") {
    return {
      ".tag": "folder",
      id: "root",
      name: "home",
      path_display: "/",
      path_lower: "/",
    };
  }

  try {
    return await dropboxRequest<DropboxMetadata>(accessToken, "files/get_metadata", {
      method: "POST",
      body: JSON.stringify({path: normalizedPath}),
    }, pathRootHeader);
  } catch (error) {
    if (error instanceof HttpsError && error.message.includes("path/not_found")) {
      return null;
    }
    throw error;
  }
}

async function ensureDropboxFolderPath(
  accessToken: string,
  rootPath: string,
  relativePath: string,
  pathRootHeader?: string
) {
  const normalizedRootPath = normalizeDropboxPath(rootPath);
  if (normalizedRootPath === "/") {
    throw new HttpsError("failed-precondition", "Dropbox 프로젝트 루트 경로가 유효하지 않습니다.");
  }

  let currentPath = normalizedRootPath;
  const segments = relativePath
    .split("/")
    .map((segment) => sanitizeFolderName(segment))
    .map((segment) => segment.trim())
    .filter((segment) => segment.length > 0);

  for (const segment of segments) {
    const nextPath = joinDropboxPath(currentPath, segment);
    const metadata = await getDropboxMetadata(accessToken, nextPath, pathRootHeader);
    if (!metadata || metadata[".tag"] !== "folder") {
      await dropboxRequest<{metadata: DropboxMetadata}>(accessToken, "files/create_folder_v2", {
        method: "POST",
        body: JSON.stringify({path: nextPath, autorename: false}),
      }, pathRootHeader);
    }
    currentPath = nextPath;
  }

  return currentPath;
}

async function ensureDropboxFolderPathWithMetadata(
  accessToken: string,
  rootPath: string,
  relativePath: string,
  pathRootHeader?: string
): Promise<DropboxMetadata> {
  const folderPath = await ensureDropboxFolderPath(accessToken, rootPath, relativePath, pathRootHeader);
  const metadata = await getDropboxMetadata(accessToken, folderPath, pathRootHeader);
  if (!metadata) {
    throw new HttpsError("failed-precondition", "Dropbox 폴더 메타데이터를 조회하지 못했습니다.");
  }
  if (metadata[".tag"] !== "folder") {
    throw new HttpsError("failed-precondition", "Dropbox 경로가 폴더가 아닙니다.");
  }
  return metadata;
}

async function listDropboxFolder(
  accessToken: string,
  folderPath: string,
  pathRootHeader?: string
): Promise<DropboxMetadata[]> {
  const normalizedPath = normalizeDropboxPath(folderPath);
  const response = await dropboxRequest<DropboxListFolderResponse>(accessToken, "files/list_folder", {
    method: "POST",
    body: JSON.stringify({
      path: normalizedPath === "/" ? "" : normalizedPath,
      recursive: false,
      include_media_info: false,
      include_deleted: false,
      include_has_explicit_shared_members: false,
      include_mounted_folders: true,
      include_non_downloadable_files: true,
    }),
  }, pathRootHeader);

  return response.entries ?? [];
}

async function deleteDropboxItem(accessToken: string, path: string, pathRootHeader?: string) {
  const normalizedPath = normalizeDropboxPath(path);
  if (normalizedPath === "/") {
    throw new HttpsError("failed-precondition", "Dropbox 루트 경로는 삭제할 수 없습니다.");
  }

  await dropboxRequest<{metadata: DropboxMetadata}>(accessToken, "files/delete_v2", {
    method: "POST",
    body: JSON.stringify({path: normalizedPath}),
  }, pathRootHeader);
}

async function resolveArchiveDropboxFolder(
  accessToken: string,
  pathRootHeader: string | undefined,
  archiveId: string,
  requestedById: string,
  relativePath: string
) {
  const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
  if (!archiveSnapshot.exists) {
    throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
  }

  const archive = archiveSnapshot.data() ?? {};
  const memberIds = Array.isArray(archive.memberIds) ? archive.memberIds as string[] : [];
  if (!memberIds.includes(requestedById)) {
    throw new HttpsError("permission-denied", "이 프로젝트 허브의 멤버만 Dropbox 작업을 실행할 수 있습니다.");
  }

  const projectRootPath = normalizeDropboxPath(String(archive.dropboxRootPath ?? "").trim());
  if (projectRootPath === "/") {
    throw new HttpsError("failed-precondition", "Dropbox 프로젝트 폴더가 아직 준비되지 않았습니다.");
  }

  const storageFolders = Array.isArray(archive.storageFolders)
    ? (archive.storageFolders as ArchiveStorageFolder[])
    : [];
  const requestedFolder = storageFolders.find((folder) =>
    folder.provider === "dropbox" &&
    String(folder.relativePath ?? "").trim() === relativePath
  );
  if (!requestedFolder) {
    throw new HttpsError("not-found", "요청한 Dropbox 폴더 구성을 찾지 못했습니다.");
  }

  const folderPath = joinDropboxPath(projectRootPath, String(requestedFolder.relativePath ?? "").trim());
  await ensureDropboxFolderPath(
    accessToken,
    projectRootPath,
    String(requestedFolder.relativePath ?? "").trim(),
    pathRootHeader
  );

  return {
    archive,
    archiveRef: archiveSnapshot.ref,
    folderPath,
    folderConfig: requestedFolder,
  };
}

async function driveRequest<T>(
  accessToken: string,
  input: string,
  init?: RequestInit
): Promise<T> {
  const response = await fetch(input, {
    ...init,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

  if (!response.ok) {
    const text = await response.text();
    logger.error("Google Drive API request failed", {
      input,
      status: response.status,
      text,
    });
    throw new HttpsError("internal", "Google Drive API 요청에 실패했습니다.");
  }

  return await response.json() as T;
}

async function fetchSharedDrive(accessToken: string) {
  const sharedDriveId = googleDriveSharedDriveId.value();
  return await driveRequest<{id: string; name: string}>(
    accessToken,
    `https://www.googleapis.com/drive/v3/drives/${sharedDriveId}`
  );
}

async function fetchFolderMetadata(accessToken: string, folderId: string) {
  const url = new URL(`https://www.googleapis.com/drive/v3/files/${folderId}`);
  url.searchParams.set("fields", "id,name,mimeType,webViewLink,driveId,parents");
  url.searchParams.set("supportsAllDrives", "true");

  return await driveRequest<DriveFile>(accessToken, url.toString());
}

async function findFolderByName(
  accessToken: string,
  parentId: string,
  folderName: string
) {
  const query = [
    `'${escapeDriveQueryValue(parentId)}' in parents`,
    "trashed = false",
    "mimeType = 'application/vnd.google-apps.folder'",
    `name = '${escapeDriveQueryValue(folderName)}'`,
  ].join(" and ");

  const url = new URL("https://www.googleapis.com/drive/v3/files");
  url.searchParams.set("q", query);
  url.searchParams.set("fields", "files(id,name,mimeType,webViewLink,driveId)");
  url.searchParams.set("supportsAllDrives", "true");
  url.searchParams.set("includeItemsFromAllDrives", "true");
  url.searchParams.set("corpora", "drive");
  url.searchParams.set("driveId", googleDriveSharedDriveId.value());
  url.searchParams.set("pageSize", "10");

  const response = await driveRequest<{files?: DriveFile[]}>(
    accessToken,
    url.toString(),
    {method: "GET"}
  );

  return response.files?.[0] ?? null;
}

async function createFolder(
  accessToken: string,
  parentId: string,
  folderName: string
) {
  return await driveRequest<DriveFile>(
    accessToken,
    "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true&fields=id,name,mimeType,webViewLink,driveId,parents",
    {
      method: "POST",
      body: JSON.stringify({
        name: folderName,
        mimeType: "application/vnd.google-apps.folder",
        parents: [parentId],
      }),
    }
  );
}

async function ensureFolder(
  accessToken: string,
  parentId: string,
  folderName: string
) {
  const existing = await findFolderByName(accessToken, parentId, folderName);
  if (existing) {
    return existing;
  }
  return await createFolder(accessToken, parentId, folderName);
}

async function ensureFolderPath(
  accessToken: string,
  rootFolderId: string,
  relativePath: string
) {
  const segments = relativePath
    .split("/")
    .map((segment) => sanitizeFolderName(segment))
    .filter((segment) => segment.length > 0);

  let currentParentId = rootFolderId;
  let currentFolder = await fetchFolderMetadata(accessToken, rootFolderId);

  for (const segment of segments) {
    currentFolder = await ensureFolder(accessToken, currentParentId, segment);
    currentParentId = currentFolder.id;
  }

  return currentFolder;
}

async function listFolderContents(
  accessToken: string,
  folderId: string
) {
  const query = [
    `'${escapeDriveQueryValue(folderId)}' in parents`,
    "trashed = false",
  ].join(" and ");

  const url = new URL("https://www.googleapis.com/drive/v3/files");
  url.searchParams.set("q", query);
  url.searchParams.set("fields", "files(id,name,mimeType,webViewLink,driveId,parents,size,modifiedTime,iconLink)");
  url.searchParams.set("supportsAllDrives", "true");
  url.searchParams.set("includeItemsFromAllDrives", "true");
  url.searchParams.set("corpora", "drive");
  url.searchParams.set("driveId", googleDriveSharedDriveId.value());
  url.searchParams.set("pageSize", "200");
  url.searchParams.set("orderBy", "folder,name_natural");

  const response = await driveRequest<{files?: DriveFile[]}>(
    accessToken,
    url.toString(),
    {method: "GET"}
  );

  return response.files ?? [];
}

async function createGoogleDriveUploadSession(
  accessToken: string,
  parentFolderId: string,
  fileName: string,
  mimeType: string,
  relativePath: string,
  description: string,
  keywords: string[],
  folderTitle: string,
  archiveName: string | undefined,
  archiveId: string,
  requestedById: string
) {
  const indexableTokens = [
    archiveName ? `archive:${sanitizeFolderName(archiveName)}` : "",
    `path:${relativePath}`,
    `folder:${folderTitle}`,
    description,
    ...keywords,
  ].filter(Boolean);

  const appProperties: Record<string, string> = {
    archiveId,
    requestedById,
    projectFolder: sanitizeFolderName(archiveName ?? ""),
    relativePath,
    folderTitle: sanitizeFolderName(folderTitle),
  };
  if (keywords.length > 0) {
    appProperties.keywords = keywords.join(",");
  }

  const response = await fetch(
    "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&supportsAllDrives=true&fields=id,name,mimeType,webViewLink,iconLink,thumbnailLink,size,modifiedTime,parents",
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
        "X-Upload-Content-Type": mimeType,
      },
      body: JSON.stringify({
        name: fileName,
        parents: [parentFolderId],
        description,
        appProperties,
        ...(indexableTokens.length > 0
          ? {contentHints: {indexableText: indexableTokens.join(" | ")}}
          : {}),
      }),
    }
  );

  if (!response.ok) {
    const text = await response.text();
    logger.error("Google Drive resumable session creation failed", {
      status: response.status,
      text,
      parentFolderId,
      fileName,
    });
    throw new HttpsError("internal", "Google Drive 업로드 세션 생성에 실패했습니다.");
  }

  const uploadUrl = response.headers.get("location");
  if (!uploadUrl) {
    throw new HttpsError("internal", "Google Drive 업로드 URL을 받지 못했습니다.");
  }

  const uploadUrlWithFields = new URL(uploadUrl);
  uploadUrlWithFields.searchParams.set(
    "fields",
    "id,name,mimeType,webViewLink,iconLink,thumbnailLink,size,modifiedTime"
  );
  return uploadUrlWithFields.toString();
}

async function createDropboxUploadSession(
  accessToken: string,
  folderPath: string,
  fileName: string,
  pathRootHeader?: string
) {
  const sanitizedFileName = sanitizeFolderName(fileName);
  if (!sanitizedFileName) {
    throw new HttpsError("invalid-argument", "업로드할 파일명이 유효하지 않습니다.");
  }

  return {
    accessToken,
    uploadPath: joinDropboxPath(folderPath, sanitizedFileName),
    folderPath,
    webViewLink: buildDropboxWebURL(joinDropboxPath(folderPath, sanitizedFileName)),
    pathRootHeader,
  };
}

async function deleteDriveItem(accessToken: string, fileId: string) {
  const response = await fetch(
    `https://www.googleapis.com/drive/v3/files/${fileId}?supportsAllDrives=true`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    }
  );

  if (!response.ok) {
    const text = await response.text();
    logger.error("Google Drive delete failed", {fileId, status: response.status, text});
    throw new HttpsError("internal", "Google Drive 프로젝트 폴더 삭제에 실패했습니다.");
  }
}

async function isDescendantOfRoot(
  accessToken: string,
  folderId: string,
  rootFolderId: string,
  maxDepth = 3
) {
  let currentFolderId: string | null = folderId;
  let depth = 0;

  while (currentFolderId && depth < maxDepth) {
    const metadata = await fetchFolderMetadata(accessToken, currentFolderId);
    const parents = metadata.parents ?? [];
    if (parents.includes(rootFolderId)) {
      return true;
    }
    currentFolderId = parents[0] ?? null;
    depth += 1;
  }

  return false;
}

function getAuthDisplayName(auth: {token: Record<string, unknown>}) {
  return String(auth.token.name ?? auth.token.email ?? "portal-admin");
}

async function getDirectoryEmailForUser(userId: string) {
  const snapshot = await db.collection("directoryUsers").doc(userId).get();
  return String(snapshot.data()?.emailLowercased ?? snapshot.data()?.email ?? "").toLowerCase();
}

async function resolveArchiveGoogleDriveFolder(
  accessToken: string,
  archiveId: string,
  requestedById: string,
  relativePath: string
) {
  const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
  if (!archiveSnapshot.exists) {
    throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
  }

  const archive = archiveSnapshot.data() ?? {};
  const memberIds = Array.isArray(archive.memberIds) ? archive.memberIds as string[] : [];
  if (!memberIds.includes(requestedById)) {
    throw new HttpsError("permission-denied", "이 프로젝트 허브의 멤버만 Google Drive 작업을 실행할 수 있습니다.");
  }

  const projectRootFolderId = String(archive.googleDriveRootFolderId ?? "").trim();
  if (!projectRootFolderId) {
    throw new HttpsError("failed-precondition", "Google Drive 프로젝트 폴더가 아직 준비되지 않았습니다.");
  }

  const storageFolders = Array.isArray(archive.storageFolders)
    ? (archive.storageFolders as ArchiveStorageFolder[])
    : [];
  const requestedFolder = storageFolders.find((folder) =>
    folder.provider === "googleDrive" &&
    String(folder.relativePath ?? "").trim() === relativePath
  );
  if (!requestedFolder) {
    throw new HttpsError("not-found", "요청한 Google Drive 폴더 구성을 찾지 못했습니다.");
  }

  const ensuredFolder = await ensureFolderPath(accessToken, projectRootFolderId, relativePath);
  return {
    archive,
    archiveRef: archiveSnapshot.ref,
    folder: ensuredFolder,
    folderConfig: requestedFolder,
  };
}

async function setJobState(
  jobRef: admin.firestore.DocumentReference,
  patch: Partial<ProjectArchiveJob>
) {
  await jobRef.set(
    {
      ...patch,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(patch.status === "completed" || patch.status === "failed"
        ? {completedAt: admin.firestore.FieldValue.serverTimestamp()}
        : {}),
    },
    {merge: true}
  );
}

export const getExternalStorageAdminStatus = onCall(async (request) => {
  const auth = requireAuth(request.auth);
  requireAdmin(auth);

  const snapshot = await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).get();
  return {
    documentPath: EXTERNAL_STORAGE_ACCOUNTS_PATH,
    document: snapshot.exists ? asExternalStorageDocument(snapshot) : null,
  };
});

export const updateExternalStorageAdminStatus = onCall(async (request) => {
  const auth = requireAuth(request.auth);
  const adminEmail = requireAdmin(auth);

  const data = (request.data ?? {}) as Partial<ExternalStorageAccountsDocument>;
  const currentSnapshot = await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).get();
  const currentDocument = asExternalStorageDocument(currentSnapshot);

  const nextDocument: ExternalStorageAccountsDocument = {
    googleDrive: mergeProviderStatus(currentDocument.googleDrive, data.googleDrive ?? {}),
    dropbox: mergeProviderStatus(currentDocument.dropbox, data.dropbox ?? {}),
    updatedAt: admin.firestore.Timestamp.now(),
    updatedByEmail: adminEmail,
    updatedByName: getAuthDisplayName(auth),
  };

  await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).set(nextDocument, {merge: true});
  return {ok: true};
});

export const validateGoogleDriveAdminSetup = onCall(
  {
    secrets: [
      googleDriveClientId,
      googleDriveClientSecret,
      googleDriveRefreshToken,
      googleDriveSharedDriveId,
      googleDriveProjectHubRootFolderId,
    ],
  },
  async (request): Promise<GoogleDriveValidationResponse> => {
    const auth = requireAuth(request.auth);
    const adminEmail = requireAdmin(auth);

    const accessToken = await getGoogleDriveAccessToken();
    const sharedDrive = await fetchSharedDrive(accessToken);
    const rootFolder = await fetchFolderMetadata(
      accessToken,
      googleDriveProjectHubRootFolderId.value()
    );

    if (rootFolder.mimeType !== "application/vnd.google-apps.folder") {
      throw new HttpsError("failed-precondition", "Project Hub Root가 폴더가 아닙니다.");
    }

    if (rootFolder.driveId && rootFolder.driveId !== sharedDrive.id) {
      throw new HttpsError("failed-precondition", "Project Hub Root가 지정한 Shared Drive에 속하지 않습니다.");
    }

    const currentSnapshot = await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).get();
    const currentDocument = asExternalStorageDocument(currentSnapshot);
    const notes = `${sharedDrive.name} / ${rootFolder.name}`;

    await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).set(
      {
        googleDrive: mergeProviderStatus(currentDocument.googleDrive, {
          executionEmail: "pd@studioleaf.kr",
          accountLabel: sharedDrive.name,
          connectionState: "connected",
          notes,
          lastValidatedAt: admin.firestore.Timestamp.now(),
        }),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedByEmail: adminEmail,
        updatedByName: getAuthDisplayName(auth),
      },
      {merge: true}
    );

    return {
      sharedDrive,
      rootFolder: {
        id: rootFolder.id,
        name: rootFolder.name,
        webViewLink: rootFolder.webViewLink ?? `https://drive.google.com/drive/folders/${rootFolder.id}`,
        driveId: rootFolder.driveId,
      },
    };
  }
);

export const provisionGoogleDriveProjectFolders = onCall(
  {
    secrets: [
      googleDriveClientId,
      googleDriveClientSecret,
      googleDriveRefreshToken,
      googleDriveSharedDriveId,
      googleDriveProjectHubRootFolderId,
    ],
  },
  async (request): Promise<GoogleDriveProvisionResponse> => {
    const auth = requireAuth(request.auth);
    const archiveId = String((request.data as {archiveId?: string} | undefined)?.archiveId ?? "").trim();
    if (!archiveId) {
      throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
    }

    const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
    if (!archiveSnapshot.exists) {
      throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
    }

    const archive = archiveSnapshot.data() ?? {};
    const memberIds = Array.isArray(archive.memberIds) ? archive.memberIds as string[] : [];
    if (!memberIds.includes(auth.uid)) {
      throw new HttpsError("permission-denied", "이 프로젝트 허브의 멤버만 Google Drive 폴더를 만들 수 있습니다.");
    }

    const projectName = sanitizeFolderName(String(archive.name ?? ""));
    if (!projectName) {
      throw new HttpsError("failed-precondition", "프로젝트 이름이 비어 있습니다.");
    }

    const storageFolders = Array.isArray(archive.storageFolders)
      ? (archive.storageFolders as ArchiveStorageFolder[])
      : [];
    const googleFolders = storageFolders
      .filter((folder) => folder.provider === "googleDrive")
      .sort((left, right) => (left.sortOrder ?? 0) - (right.sortOrder ?? 0));

    const requestedYear = Number((request.data as {year?: number} | undefined)?.year);
    const year = Number.isFinite(requestedYear) && requestedYear > 0
      ? String(Math.trunc(requestedYear))
      : String(new Date().getFullYear());
    const projectFolderName = sanitizeFolderName(`${year}_${projectName}`);

    const accessToken = await getGoogleDriveAccessToken();
    const yearFolder = await ensureFolder(
      accessToken,
      googleDriveProjectHubRootFolderId.value(),
      year
    );
    const projectFolder = await ensureFolder(
      accessToken,
      yearFolder.id,
      projectFolderName
    );

    const createdFolders: GoogleDriveProvisionResponse["createdFolders"] = [];
    for (const folder of googleFolders) {
      const relativePath = String(folder.relativePath ?? "").trim();
      if (!relativePath) {
        continue;
      }

      const ensuredFolder = await ensureFolderPath(accessToken, projectFolder.id, relativePath);
      createdFolders.push({
        id: ensuredFolder.id,
        name: ensuredFolder.name,
        webViewLink: ensuredFolder.webViewLink ?? `https://drive.google.com/drive/folders/${ensuredFolder.id}`,
        relativePath,
      });
    }

    await archiveSnapshot.ref.set(
      {
        googleDriveRootFolderId: projectFolder.id,
        googleDriveRootTitle: projectFolder.name,
        googleDriveRootWebURL: projectFolder.webViewLink ?? `https://drive.google.com/drive/folders/${projectFolder.id}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    return {
      archiveId,
      yearFolder: {
        id: yearFolder.id,
        name: yearFolder.name,
        webViewLink: yearFolder.webViewLink ?? `https://drive.google.com/drive/folders/${yearFolder.id}`,
      },
      projectFolder: {
        id: projectFolder.id,
        name: projectFolder.name,
        webViewLink: projectFolder.webViewLink ?? `https://drive.google.com/drive/folders/${projectFolder.id}`,
      },
      createdFolders,
    };
  }
);

export const deleteGoogleDriveProjectFolders = onCall(
  {
    secrets: [
      googleDriveClientId,
      googleDriveClientSecret,
      googleDriveRefreshToken,
      googleDriveSharedDriveId,
      googleDriveProjectHubRootFolderId,
    ],
  },
  async (request): Promise<GoogleDriveDeleteResponse> => {
    const auth = requireAuth(request.auth);
    const archiveId = String((request.data as {archiveId?: string} | undefined)?.archiveId ?? "").trim();
    if (!archiveId) {
      throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
    }

    const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
    if (!archiveSnapshot.exists) {
      throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
    }

    const archive = archiveSnapshot.data() ?? {};
    const ownerId = String(archive.ownerId ?? "");
    if (ownerId !== auth.uid) {
      throw new HttpsError("permission-denied", "이 프로젝트 허브를 삭제할 권한이 없습니다.");
    }

    const googleDriveFolderId = String(archive.googleDriveRootFolderId ?? "").trim();
    if (!googleDriveFolderId) {
      return {
        archiveId,
        deletedFolderId: "",
      };
    }

    const accessToken = await getGoogleDriveAccessToken();
    const folderMetadata = await fetchFolderMetadata(accessToken, googleDriveFolderId);
    const expectedRootId = googleDriveProjectHubRootFolderId.value();
    const isUnderRoot = await isDescendantOfRoot(accessToken, googleDriveFolderId, expectedRootId);
    if (!isUnderRoot) {
      throw new HttpsError("failed-precondition", "삭제 대상 폴더가 Project Hub Root 바로 아래 프로젝트 폴더가 아닙니다.");
    }

    await deleteDriveItem(accessToken, googleDriveFolderId);

    return {
      archiveId,
      deletedFolderId: googleDriveFolderId,
    };
  }
);

export const processProjectArchiveJob = onDocumentCreated(
  {
    document: `${PROJECT_ARCHIVE_JOBS_PATH}/{jobId}`,
    region: "us-central1",
    secrets: [
      googleDriveClientId,
      googleDriveClientSecret,
      googleDriveRefreshToken,
      googleDriveSharedDriveId,
      googleDriveProjectHubRootFolderId,
      dropboxAppKey,
      dropboxAppSecret,
      dropboxRefreshToken,
    ],
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      return;
    }

    const jobRef = snapshot.ref;
    const job = snapshot.data() as ProjectArchiveJob;
    await setJobState(jobRef, {status: "running", errorMessage: admin.firestore.FieldValue.delete() as unknown as string});

    try {
      const requesterEmail = await getDirectoryEmailForUser(job.requestedById);

      switch (job.type) {
      case "validateGoogleDriveAdmin": {
        if (!ADMIN_EMAILS.has(requesterEmail)) {
          throw new HttpsError("permission-denied", "관리자만 Google Drive 연결 검증을 실행할 수 있습니다.");
        }

        const accessToken = await getGoogleDriveAccessToken();
        const sharedDrive = await fetchSharedDrive(accessToken);
        const rootFolder = await fetchFolderMetadata(
          accessToken,
          googleDriveProjectHubRootFolderId.value()
        );

        const currentSnapshot = await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).get();
        const currentDocument = asExternalStorageDocument(currentSnapshot);
        await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).set(
          {
            googleDrive: mergeProviderStatus(currentDocument.googleDrive, {
              executionEmail: "pd@studioleaf.kr",
              accountLabel: sharedDrive.name,
              connectionState: "connected",
              notes: `${sharedDrive.name} / ${rootFolder.name}`,
              lastValidatedAt: admin.firestore.Timestamp.now(),
            }),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedByEmail: requesterEmail,
            updatedByName: requesterEmail,
          },
          {merge: true}
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            sharedDriveName: sharedDrive.name,
            rootFolderName: rootFolder.name,
            rootFolderId: rootFolder.id,
          },
        });
        break;
      }
      case "validateDropboxAdmin": {
        if (!ADMIN_EMAILS.has(requesterEmail)) {
          throw new HttpsError("permission-denied", "관리자만 Dropbox 연결 검증을 실행할 수 있습니다.");
        }

        const rootPath = normalizeDropboxPath(DEFAULT_DROPBOX_ROOT_PATH);
        const accessToken = await getDropboxAccessToken();
        const account = await getDropboxCurrentAccount(accessToken);
        const pathRootHeader = makeDropboxPathRootHeader(account);
        const rootMetadata = await getDropboxMetadata(accessToken, rootPath, pathRootHeader);
        if (!rootMetadata || rootMetadata[".tag"] !== "folder") {
          throw new HttpsError("failed-precondition", "Dropbox 루트 경로가 폴더가 아니거나 존재하지 않습니다.");
        }

        const currentSnapshot = await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).get();
        const currentDocument = asExternalStorageDocument(currentSnapshot);
        await db.doc(EXTERNAL_STORAGE_ACCOUNTS_PATH).set(
          {
            dropbox: mergeProviderStatus(currentDocument.dropbox, {
              executionEmail: "pd@studioleaf.kr",
              accountLabel: account.name.display_name,
              connectionState: "connected",
              notes: `${account.email} / ${rootMetadata.name}`,
              lastValidatedAt: admin.firestore.Timestamp.now(),
            }),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedByEmail: requesterEmail,
            updatedByName: requesterEmail,
          },
          {merge: true}
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            account: {
              accountId: account.account_id,
              email: account.email,
              name: account.name.display_name,
            },
            rootPath,
          },
        });
        break;
      }
      case "provisionGoogleDriveFolders": {
        const archiveId = String(job.archiveId ?? "").trim();
        if (!archiveId) {
          throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
        }

        const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
        if (!archiveSnapshot.exists) {
          throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
        }

        const archive = archiveSnapshot.data() ?? {};
        const memberIds = Array.isArray(archive.memberIds) ? archive.memberIds as string[] : [];
        if (!memberIds.includes(job.requestedById)) {
          throw new HttpsError("permission-denied", "이 프로젝트 허브의 멤버만 Google Drive 폴더를 만들 수 있습니다.");
        }

        const projectName = sanitizeFolderName(String(archive.name ?? ""));
        if (!projectName) {
          throw new HttpsError("failed-precondition", "프로젝트 이름이 비어 있습니다.");
        }

        const storageFolders = Array.isArray(archive.storageFolders)
          ? (archive.storageFolders as ArchiveStorageFolder[])
          : [];
        const googleFolders = storageFolders
          .filter((folder) => folder.provider === "googleDrive")
          .sort((left, right) => (left.sortOrder ?? 0) - (right.sortOrder ?? 0));

        const year = Number.isFinite(job.year) && Number(job.year) > 0
          ? String(Math.trunc(Number(job.year)))
          : String(new Date().getFullYear());
        const projectFolderName = sanitizeFolderName(`${year}_${projectName}`);

        const accessToken = await getGoogleDriveAccessToken();
        const yearFolder = await ensureFolder(
          accessToken,
          googleDriveProjectHubRootFolderId.value(),
          year
        );
        const projectFolder = await ensureFolder(
          accessToken,
          yearFolder.id,
          projectFolderName
        );

        const createdFolders: Array<Record<string, string>> = [];
        for (const folder of googleFolders) {
          const relativePath = String(folder.relativePath ?? "").trim();
          if (!relativePath) {
            continue;
          }

          const ensuredFolder = await ensureFolderPath(accessToken, projectFolder.id, relativePath);
          createdFolders.push({
            id: ensuredFolder.id,
            name: ensuredFolder.name,
            relativePath,
            webViewLink: ensuredFolder.webViewLink ?? `https://drive.google.com/drive/folders/${ensuredFolder.id}`,
          });
        }

        await archiveSnapshot.ref.set(
          {
            googleDriveRootFolderId: projectFolder.id,
            googleDriveRootTitle: projectFolder.name,
            googleDriveRootWebURL: projectFolder.webViewLink ?? `https://drive.google.com/drive/folders/${projectFolder.id}`,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            archiveId,
            projectFolderId: projectFolder.id,
            projectFolderName: projectFolder.name,
            yearFolderId: yearFolder.id,
            createdFolders,
          },
        });
        break;
      }
      case "provisionDropboxFolders": {
        const archiveId = String(job.archiveId ?? "").trim();
        if (!archiveId) {
          throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
        }

        const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
        if (!archiveSnapshot.exists) {
          throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
        }

        const archive = archiveSnapshot.data() ?? {};
        const memberIds = Array.isArray(archive.memberIds) ? archive.memberIds as string[] : [];
        if (!memberIds.includes(job.requestedById)) {
          throw new HttpsError("permission-denied", "이 프로젝트 허브의 멤버만 Dropbox 폴더를 만들 수 있습니다.");
        }

        const projectName = sanitizeFolderName(String(archive.name ?? ""));
        if (!projectName) {
          throw new HttpsError("failed-precondition", "프로젝트 이름이 비어 있습니다.");
        }

        const storageFolders = Array.isArray(archive.storageFolders)
          ? (archive.storageFolders as ArchiveStorageFolder[])
          : [];
        const dropboxFolders = storageFolders
          .filter((folder) => folder.provider === "dropbox")
          .sort((left, right) => (left.sortOrder ?? 0) - (right.sortOrder ?? 0));

        const year = Number.isFinite(job.year) && Number(job.year) > 0
          ? String(Math.trunc(Number(job.year)))
          : String(new Date().getFullYear());
        const projectFolderName = sanitizeFolderName(`${year}_${projectName}`);
        const configuredRootPath = normalizeDropboxPath(String(archive.dropboxRootPath ?? "").trim());
        const baseRootPath = configuredRootPath === "/" ? DEFAULT_DROPBOX_ROOT_PATH : configuredRootPath;

        const accessToken = await getDropboxAccessToken();
        const account = await getDropboxCurrentAccount(accessToken);
        const pathRootHeader = makeDropboxPathRootHeader(account);
        const rootMetadata = await getDropboxMetadata(accessToken, baseRootPath, pathRootHeader);
        if (!rootMetadata || rootMetadata[".tag"] !== "folder") {
          throw new HttpsError("failed-precondition", "Dropbox 루트 경로가 준비되지 않았습니다.");
        }

        const yearFolder = await ensureDropboxFolderPathWithMetadata(
          accessToken,
          baseRootPath,
          year,
          pathRootHeader
        );
        const projectFolder = await ensureDropboxFolderPathWithMetadata(
          accessToken,
          yearFolder.path_display ?? baseRootPath,
          projectFolderName,
          pathRootHeader
        );

        const createdFolders: Array<Record<string, string>> = [];
        for (const folder of dropboxFolders) {
          const relativePath = String(folder.relativePath ?? "").trim();
          if (!relativePath) {
            continue;
          }

          const ensuredPath = await ensureDropboxFolderPathWithMetadata(
            accessToken,
            projectFolder.path_display ?? baseRootPath,
            relativePath,
            pathRootHeader
          );
          createdFolders.push({
            id: ensuredPath.id,
            name: ensuredPath.name,
            relativePath,
            webViewLink: buildDropboxWebURL(ensuredPath.path_display ?? ensuredPath.id),
            path: ensuredPath.path_display ?? ensuredPath.id,
          });
        }

        const projectRootPath = normalizeDropboxPath(projectFolder.path_display ?? "");
        const projectRootWebURL = buildDropboxWebURL(projectRootPath);

        await archiveSnapshot.ref.set(
          {
            dropboxRootPath: projectRootPath,
            dropboxRootTitle: projectFolder.name,
            dropboxRootWebURL: projectRootWebURL,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true}
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            archiveId,
            projectRootPath,
            projectRootTitle: projectFolder.name,
            projectRootWebURL,
            createdFolders,
          },
        });
        break;
      }
      case "deleteGoogleDriveFolders": {
        const archiveId = String(job.archiveId ?? "").trim();
        if (!archiveId) {
          throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
        }

        const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
        if (!archiveSnapshot.exists) {
          throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
        }

        const archive = archiveSnapshot.data() ?? {};
        const ownerId = String(archive.ownerId ?? "");
        if (ownerId !== job.requestedById) {
          throw new HttpsError("permission-denied", "이 프로젝트 허브를 삭제할 권한이 없습니다.");
        }

        const googleDriveFolderId = String(archive.googleDriveRootFolderId ?? "").trim();
        if (!googleDriveFolderId) {
          await setJobState(jobRef, {
            status: "completed",
            result: {archiveId, deletedFolderId: ""},
          });
          break;
        }

        const accessToken = await getGoogleDriveAccessToken();
        const isUnderRoot = await isDescendantOfRoot(
          accessToken,
          googleDriveFolderId,
          googleDriveProjectHubRootFolderId.value()
        );
        if (!isUnderRoot) {
          throw new HttpsError("failed-precondition", "삭제 대상 폴더가 Project Hub Root 하위에 없습니다.");
        }

        await deleteDriveItem(accessToken, googleDriveFolderId);
        await setJobState(jobRef, {
          status: "completed",
          result: {archiveId, deletedFolderId: googleDriveFolderId},
        });
        break;
      }
      case "deleteDropboxFolders": {
        const archiveId = String(job.archiveId ?? "").trim();
        if (!archiveId) {
          throw new HttpsError("invalid-argument", "archiveId가 필요합니다.");
        }

        const archiveSnapshot = await db.collection("projectArchives").doc(archiveId).get();
        if (!archiveSnapshot.exists) {
          throw new HttpsError("not-found", "프로젝트 허브 문서를 찾지 못했습니다.");
        }

        const archive = archiveSnapshot.data() ?? {};
        const ownerId = String(archive.ownerId ?? "");
        if (ownerId !== job.requestedById) {
          throw new HttpsError("permission-denied", "이 프로젝트 허브를 삭제할 권한이 없습니다.");
        }

        const projectRootPath = normalizeDropboxPath(String(archive.dropboxRootPath ?? "").trim());
        if (!projectRootPath || projectRootPath === "/") {
          await setJobState(jobRef, {
            status: "completed",
            result: {archiveId, deletedPath: ""},
          });
          break;
        }

        const normalizedBase = DEFAULT_DROPBOX_ROOT_PATH;
        if (projectRootPath === normalizedBase) {
          throw new HttpsError(
            "failed-precondition",
            "Dropbox 기본 루트는 삭제할 수 없습니다."
          );
        }

        if (!isPathUnderDropboxRoot(normalizedBase, projectRootPath)) {
          throw new HttpsError("failed-precondition", "삭제 대상 폴더가 Dropbox 프로젝트 루트 하위에 없습니다.");
        }

        const accessToken = await getDropboxAccessToken();
        const account = await getDropboxCurrentAccount(accessToken);
        const pathRootHeader = makeDropboxPathRootHeader(account);
        const metadata = await getDropboxMetadata(accessToken, projectRootPath, pathRootHeader);
        if (!metadata) {
          await setJobState(jobRef, {
            status: "completed",
            result: {archiveId, deletedPath: ""},
          });
          break;
        }

        if (metadata[".tag"] !== "folder") {
          throw new HttpsError("failed-precondition", "Dropbox 삭제 대상이 폴더가 아닙니다.");
        }

        await deleteDropboxItem(accessToken, projectRootPath, pathRootHeader);

        await setJobState(jobRef, {
          status: "completed",
          result: {archiveId, deletedPath: projectRootPath},
        });
        break;
      }
      case "listGoogleDriveFolderContents": {
        const archiveId = String(job.archiveId ?? "").trim();
        const relativePath = String((snapshot.data() as Record<string, unknown>).relativePath ?? "").trim();
        if (!archiveId || !relativePath) {
          throw new HttpsError("invalid-argument", "archiveId와 relativePath가 필요합니다.");
        }

        const accessToken = await getGoogleDriveAccessToken();
        const resolved = await resolveArchiveGoogleDriveFolder(
          accessToken,
          archiveId,
          job.requestedById,
          relativePath
        );
        const items = await listFolderContents(accessToken, resolved.folder.id);

        await setJobState(jobRef, {
          status: "completed",
          result: {
            folderId: resolved.folder.id,
            folderTitle: resolved.folderConfig.title,
            relativePath,
            items: items.map((item) => ({
              id: item.id,
              name: item.name,
              mimeType: item.mimeType ?? "application/octet-stream",
              webViewLink: item.webViewLink ?? `https://drive.google.com/file/d/${item.id}/view`,
              sizeBytes: item.size ? Number(item.size) : 0,
              modifiedAtSeconds: item.modifiedTime ? Math.floor(new Date(item.modifiedTime).getTime() / 1000) : null,
              iconLink: item.iconLink ?? "",
            })),
          },
        });
        break;
      }
      case "listDropboxFolderContents": {
        const archiveId = String(job.archiveId ?? "").trim();
        const relativePath = String((snapshot.data() as Record<string, unknown>).relativePath ?? "").trim();
        if (!archiveId || !relativePath) {
          throw new HttpsError("invalid-argument", "archiveId와 relativePath가 필요합니다.");
        }

        const accessToken = await getDropboxAccessToken();
        const account = await getDropboxCurrentAccount(accessToken);
        const pathRootHeader = makeDropboxPathRootHeader(account);
        const resolved = await resolveArchiveDropboxFolder(
          accessToken,
          pathRootHeader,
          archiveId,
          job.requestedById,
          relativePath
        );
        const items = await listDropboxFolder(accessToken, resolved.folderPath, pathRootHeader);

        await setJobState(jobRef, {
          status: "completed",
          result: {
            archiveId,
            folderPath: resolved.folderPath,
            folderTitle: resolved.folderConfig.title,
            relativePath,
            items: items.map((item) => {
              const itemPath = item.path_display ?? joinDropboxPath(resolved.folderPath, item.name);
              const webViewLink = buildDropboxWebURL(itemPath);
              return {
                id: item.id,
                name: item.name,
                pathDisplay: item.path_display ?? itemPath,
                pathLower: item.path_lower ?? itemPath.toLowerCase(),
                isFolder: item[".tag"] === "folder",
                webViewLink,
                sizeBytes: item.size ?? 0,
                modifiedAt: item.server_modified ?? item.client_modified ?? "",
              };
            }),
          },
        });
        break;
      }
      case "createGoogleDriveUploadSession": {
        const archiveId = String(job.archiveId ?? "").trim();
        const relativePath = String((snapshot.data() as Record<string, unknown>).relativePath ?? "").trim();
        const fileName = sanitizeFolderName(String((snapshot.data() as Record<string, unknown>).fileName ?? "").trim());
        const mimeType = String((snapshot.data() as Record<string, unknown>).mimeType ?? "application/octet-stream");
        if (!archiveId || !relativePath || !fileName) {
          throw new HttpsError("invalid-argument", "archiveId, relativePath, fileName이 필요합니다.");
        }

        const accessToken = await getGoogleDriveAccessToken();
        const resolved = await resolveArchiveGoogleDriveFolder(
          accessToken,
          archiveId,
          job.requestedById,
          relativePath
        );
        const uploadUrl = await createGoogleDriveUploadSession(
          accessToken,
          resolved.folder.id,
          fileName,
          mimeType,
          relativePath,
          normalizeUploadMetadataText((snapshot.data() as Record<string, unknown>).supplementaryDescription),
          normalizeUploadKeywords((snapshot.data() as Record<string, unknown>).keywords),
          resolved.folderConfig.title,
          String((resolved.archive as Record<string, unknown>).name ?? "").trim(),
          String(job.archiveId ?? "").trim(),
          job.requestedById
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            uploadUrl,
            folderId: resolved.folder.id,
            folderTitle: resolved.folderConfig.title,
            relativePath,
          },
        });
        break;
      }
      case "createDropboxUploadSession": {
        const archiveId = String(job.archiveId ?? "").trim();
        const relativePath = String((snapshot.data() as Record<string, unknown>).relativePath ?? "").trim();
        const fileName = sanitizeFolderName(String((snapshot.data() as Record<string, unknown>).fileName ?? "").trim());
        if (!archiveId || !relativePath || !fileName) {
          throw new HttpsError("invalid-argument", "archiveId, relativePath, fileName이 필요합니다.");
        }

        const accessToken = await getDropboxAccessToken();
        const account = await getDropboxCurrentAccount(accessToken);
        const pathRootHeader = makeDropboxPathRootHeader(account);
        const resolved = await resolveArchiveDropboxFolder(
          accessToken,
          pathRootHeader,
          archiveId,
          job.requestedById,
          relativePath
        );
        const uploadSession = await createDropboxUploadSession(
          accessToken,
          resolved.folderPath,
          fileName,
          pathRootHeader
        );

        await setJobState(jobRef, {
          status: "completed",
          result: {
            accessToken: uploadSession.accessToken,
            uploadPath: uploadSession.uploadPath,
            folderPath: uploadSession.folderPath,
            folderTitle: resolved.folderConfig.title,
            relativePath,
            webViewLink: uploadSession.webViewLink,
            ...(uploadSession.pathRootHeader ? {pathRootHeader: uploadSession.pathRootHeader} : {}),
          },
        });
        break;
      }
      default:
        throw new HttpsError("invalid-argument", "지원하지 않는 작업 타입입니다.");
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      logger.error("Project archive job failed", {jobId: snapshot.id, jobType: job.type, message});
      await setJobState(jobRef, {
        status: "failed",
        errorMessage: message,
      });
    }
  }
);
