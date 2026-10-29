export const environment = {
    production: false,
    apiUrl: 'http://localhost:5297',
    appName: "TransitCore",
    // Not a real secret boundary: this key ships inside the client bundle,
    // so it only obscures localStorage contents from casual inspection, not
    // from anyone with access to this source. Don't rely on it to protect
    // anything that actually needs to stay confidential.
    secretKey: "MDaL5DKcnCwbtdbDm/Rtsy9jNJjWppfOXUUBnCHfmXNUyT58cQ6Z9kQEOCM5QXRo",
    msalConfig: {
        auth: {
            clientId: 'd209c22e-c24d-4410-9495-40dc5bb3a1a8',
            authority: 'https://login.microsoftonline.com/a7281f08-3eaa-4f65-90e6-88e324f4b70d',
            redirectUri: 'http://localhost:4200',
        },
    },
    apiConfig: {
        scopes: ['user.read'],
        uri: 'https://graph.microsoft.com/v1.0/me',
    },
};
