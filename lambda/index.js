const AWS = require("aws-sdk");
const axios = require("axios");
const s3 = new AWS.S3();
const crypto = require("crypto");

const smClient = new AWS.SecretsManager({
  region: process.env.AWS_REGION,
});

const getSecrets = async (SecretId) => {
  console.log("<<< getSecrets()");
  return new Promise((resolve, reject) => {
    smClient.getSecretValue({ SecretId }, (err, result) => {
      if (err) reject(err);
      else resolve(JSON.parse(result.SecretString));
    });
    console.log(">>> getSecrets()");
  });
};

exports.handler = async (event) => {
  // Set the value of the Bitbucket Secret; required before parsing individual values
  let bbSecret;

  try {
    bbSecret = await getSecrets(process.env.BITBUCKET_SECRET_NAME);

    if (bbSecret["bitbucket_secret"].length < 1) {
      throw new Error("Bitbucket webhook signing secret is empty.");
    }
  } catch (err) {
    console.log(err);
    console.log("Failed to acquire Bitbucket Secret.");
    return responseToApiGw(500, "Error acquiring Bitbucket Secret.");
  }

  try {
    console.log(`Incoming event: ${JSON.stringify(event)}`);
    const eventBody = JSON.parse(event.body);

    // Normalize headers
    const normalizedHeaders = normalizeObject(event.headers);

    // Respond to test event
    if (
      "x-event-key" in normalizedHeaders &&
      normalizedHeaders["x-event-key"] === "diagnostics:ping"
    ) {
      return responseToApiGw(200, "Webhook configured successfully");
    }

    // Validate message signature
    if (
      !checkSignature(
        bbSecret["bitbucket_secret"],
        normalizedHeaders["x-hub-signature"],
        event.body
      )
    ) {
      console.log("Invalid webhook message signature");
      return responseToApiGw(401, "Signature is not valid");
    }
    console.log("Signature validated successfully");

    if (!(eventBody.changes[0].ref.type === "BRANCH")) {
      console.log("Invalid event type");
      throw new Error("Invalid event type");
    }

    const repoConfig = {
      serverUrl: process.env.BITBUCKET_SERVER_URL,
      projectName: eventBody.repository.project.key,
      repoName: eventBody.repository.name,
      branch: encodeURIComponent(eventBody.changes[0].ref.displayId),
      token: bbSecret["bitbucket_token"],
    };

    let proxy;
    if (process.env.WEBPROXY_HOST && process.env.WEBPROXY_PORT) {
      proxy = {
        host: process.env.WEBPROXY_HOST,
        port: process.env.WEBPROXY_PORT,
      };
    }

    // Download the repository package from Bitbucket Server
    const file = await downloadFile(repoConfig, proxy);

    // Upload the repository package to S3 bucket
    const s3Upload = await s3
      .upload({
        Bucket: process.env.S3BUCKET,
        ServerSideEncryption: "AES256",
        // Forward slashes are not allowed in S3 Object names; replace with hyphen
        Key:
          `${repoConfig.projectName}/${repoConfig.repoName}/` +
          repoConfig.branch.replace("%2F", "-") +
          ".zip",
        Body: file,
      })
      .promise();
    console.log(s3Upload);

    console.log("Exiting successfully");
    return responseToApiGw(200, "success");
  } catch (err) {
    console.log("Exiting with error", err);
    return responseToApiGw(
      500,
      "Error acquiring zip. Check Bitbucket token/secret."
    );
  }
};

/**
 * Convert an object keys to lowercase
 * @param {object} request - this is a object to convert the keys to lowercase
 * @returns {object} - return a new object with keys in lower case
 */
function normalizeObject(inputObject) {
  console.log("info", ">>> normalizeObject()");

  const requestKeys = Object.keys(inputObject);

  let outputObject = {};
  for (let i = 0; i < requestKeys.length; i++) {
    outputObject[requestKeys[i].toLowerCase()] = inputObject[requestKeys[i]];
  }

  console.log("info", "<<< normalizeObject()");
  return outputObject;
}

/**
 * Download the repository content as a zip file
 * @param {object} repoConfig - this is a object containing the config for the repository
 * @param {object} proxy - this is a object containing the web proxy configuration
 * @returns {stream} - return a stream containing the repository zip file
 */
async function downloadFile(repoConfig, proxy) {
  console.log("info", ">>> downloadFile()");
  console.log(`proxy: ${JSON.stringify(proxy)}`);
  console.log(`branch: ${repoConfig.branch}`);

  const params = {
    proxy,
    method: "get",
    baseURL: repoConfig.serverUrl,
    url: `/rest/api/latest/projects/${repoConfig.projectName}/repos/${repoConfig.repoName}/archive?at=refs/heads/${repoConfig.branch}&format=zip`,
    responseType: "stream",
    headers: {
      Authorization: `Bearer ${repoConfig.token}`,
    },
  };

  try {
    const resp = await axios.request(params);
    console.log("info", "<<< downloadFile()");
    return resp.data;
  } catch (err) {
    console.log("error", err);
    throw new Error(err);
  }
}

/**
 * Check BitBucket Server Signature
 * @param {string} signingSecret - this is the signing secret for the BitBucket Server webhook
 * @param {string} signature - this is the signatured applied by BitBucket to the message
 * @param {object} body - this is the message body
 * @returns {boolean} - return true or false
 */
function checkSignature(signingSecret, signature, body) {
  console.log("info", ">>> signingSecret()");

  const hash = crypto
    .createHmac("sha256", signingSecret)
    .update(body)
    .digest("hex");

  const signatureHash = signature.split("=");

  console.log("info", "<<< signingSecret()");
  return signatureHash[1] === hash;
}

/**
 * Generate a response for API Gateway
 * @param {string} statusCode - HTTP status code to return
 * @param {string} detail - this is message detail to return
 * @returns {object} - return the formatted response object
 */
function responseToApiGw(statusCode, detail) {
  if (!statusCode) {
    throw new TypeError(
      "responseToApiGw() expects at least argument statusCode"
    );
  }
  if (statusCode !== "200" && !detail) {
    throw new TypeError(
      "responseToApiGw() expects at least arguments statusCode and detail"
    );
  }

  let body = {};
  if (statusCode === "200" && detail) {
    body = {
      statusCode: statusCode,
      message: detail,
    };
  } else if (statusCode === "200" && !detail) {
    body = {
      statusCode: statusCode,
    };
  } else {
    body = {
      statusCode: statusCode,
      fault: detail,
    };
  }
  let response = {
    statusCode: statusCode,
    body: JSON.stringify(body),
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, GET",
      "Access-Control-Allow-Headers":
        "Origin, X-Requested-With, Content-Type, Accept",
    },
  };
  return response;
}
