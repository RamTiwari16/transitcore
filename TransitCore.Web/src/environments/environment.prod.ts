export const environment = {
    // Was `false` in the reference app - almost certainly a bug, since this
    // is the file the "production" build configuration swaps in.
    production: true,
    // Empty, not an absolute host - the standalone exe serves the Angular
    // build and the API from the same Kestrel process/port, so a relative
    // path resolves correctly on its own. A split deployment (Angular and
    // API on separate hosts) would need a real absolute URL here instead.
    apiUrl: '',
    appName: "TransitCore",
    secretKey: "MDaL5DKcnCwbtdbDm/Rtsy9jNJjWppfOXUUBnCHfmXNUyT58cQ6Z9kQEOCM5QXRo",
    msalConfig: {
        auth: {
            clientId: '4e66ebbd-58af-4e7f-a8d5-7395fcc067bf',
            authority: 'https://login.microsoftonline.com/a7281f08-3eaa-4f65-90e6-88e324f4b70d',
            // Placeholder - set the real production redirect URI before deploying.
            redirectUri: 'https://app.transitcore.example.com',
        },
    },
    apiConfig: {
        scopes: ['user.read'],
        uri: 'https://graph.microsoft.com/v1.0/me',
    },
};
