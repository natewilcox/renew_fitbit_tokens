import fetch from 'node-fetch';
import ClientOAuth2 from 'client-oauth2';
import AWS from 'aws-sdk';

import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";

//configure aws
AWS.config.update({region: 'us-east-2'});
const s3 = new AWS.S3({apiVersion: '2006-03-01'});

const getSecrets = async () => {

    const secret_name = "fitbit-api-creds";

    const client = new SecretsManagerClient({
        region: "us-east-2",
    });

    let response;

    try {
        response = await client.send(new GetSecretValueCommand({ SecretId: secret_name, VersionStage: "AWSCURRENT" }));
    } 
    catch (error) {

        // For a list of exceptions thrown, see
        // https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        throw error;
    }
      
    return JSON.parse(response.SecretString);
}

const getToday = () => {
    const easterTimeZone = 'America/New_York';
    const currentDate = new Date();
    const options = { timeZone: easterTimeZone };
    const date = new Date(currentDate.toLocaleString('en-US', options));
    const isoString = date.toISOString();
    return isoString.slice(0, 10);
}

const getSummary = (token, date) => {
    return fetch(`https://api.fitbit.com/1/user/-/activities/date/${date}.json`, {
        headers: { 
            'Authorization': ` Bearer ${token}`
        }
    });
}

const getDevices = (token) => {
    return fetch(`https://api.fitbit.com/1/user/-/devices.json`, {
        headers: { 
            'Authorization': ` Bearer ${token}`
        }
    });
}

const getTokenFile = async () => {

    var params = {
        Bucket: "fitbit-tokens", 
        Key: "tokens.json"
    };

    return s3.getObject(params).promise();
};

const putTokenFile = async (data) => {

    const params = {
        Bucket: "fitbit-tokens",
        Key: "tokens.json",
        Body: JSON.stringify(data),
        ContentType: 'application/json',
    };

    await s3.putObject(params).promise();
}

export const lambdaHandler = async (event, context) => {

    //get secrets
    const secrets = await getSecrets();

    const client = new ClientOAuth2({
        clientId: secrets.client_id,
        clientSecret: secrets.client_secret,
        accessTokenUri: 'https://api.fitbit.com/oauth2/token',
        authorizationUri: 'https://www.fitbit.com/oauth2/authorize',
        redirectUri: 'http://localhost:4200',
        scopes: ['activity', 'profile', 'settings']
    });

    try {   

        console.log('getting cached token file');
        const data = await getTokenFile();
        console.log('parsing cached token file');
        console.log(data);
        const tokens = JSON.parse(data.Body.toString());

        console.log('creating token references');

        let kenzieToken = client.createToken(tokens.kenzie.accessToken, tokens.kenzie.refreshToken);
        let nathanToken = client.createToken(tokens.nathan.accessToken, tokens.nathan.refreshToken);
        let benToken = client.createToken(tokens.ben.accessToken, tokens.ben.refreshToken);

        console.log('refreshing tokens');
        kenzieToken = await kenzieToken.refresh();
        nathanToken = await nathanToken.refresh();
        benToken = await benToken.refresh();

        console.log('writing cached token file');
        await putTokenFile({
            "updated": new Date(),
            "nathan": {
                "accessToken": nathanToken.accessToken,
                "refreshToken": nathanToken.refreshToken
            },
            "kenzie": {
                "accessToken": kenzieToken.accessToken,
                "refreshToken": kenzieToken.refreshToken
            },
            "ben": {
                "accessToken": benToken.accessToken,
                "refreshToken": benToken.refreshToken
            }
        });

        console.log('requesting fitbit api data');
        const today = getToday();
        const nathanPromise = getSummary(nathanToken.accessToken, today);
        const nathanDevicesPromise = getDevices(nathanToken.accessToken);

        const kenziePromise = getSummary(kenzieToken.accessToken, today);
        const kenzieDevicesPromise = getDevices(kenzieToken.accessToken);

        const benPromise = getSummary(benToken.accessToken, today);
        const benDevicesPromise = getDevices(benToken.accessToken);

        console.log('retrieving fitbit data');
        const [nathanData, nathanDevices, kenzieData, kenzieDevices, benData, benDevices] = await Promise.all([nathanPromise, nathanDevicesPromise, kenziePromise, kenzieDevicesPromise, benPromise, benDevicesPromise]);
        const nathan = await nathanData.json();
        const nathanDeviceData = await nathanDevices.json();

        const kenzie = await kenzieData.json();
        const kenzieDeviceData = await kenzieDevices.json();

        const ben = await benData.json();
        const benDeviceData = await benDevices.json();

        if(kenzie.errors?.length > 0 || nathan.errors?.length > 0 || ben.errors?.length > 0) {
            console.error('return error json');
            console.error(kenzie.errors);
            console.error(nathan.errors);
            console.error(ben.errors);
            return {
                'statusCode': 500,
                'headers': {
                    'Access-Control-Allow-Methods': 'GET',
                    'Access-Control-Allow-Headers': '*',
                    'Access-Control-Allow-Origin': 'https://race.natewilcox.io',
                    'Accept': '*/*',
                    'Content-Type': 'application/json' 
                },
                'body': JSON.stringify({
                    "error": "Error fetching fitbit data"
                })
            }
        }
        else {
            console.log('return payload json');
            return {
                'statusCode': 200,
                'headers': {
                    'Access-Control-Allow-Methods': 'GET',
                    'Access-Control-Allow-Headers': '*',
                    'Access-Control-Allow-Origin': 'https://race.natewilcox.io',
                    'Accept': '*/*',
                    'Content-Type': 'application/json' 
                },
                'body': JSON.stringify({
                    "date": today,
                    "kenzie": {
                        "steps": kenzie.summary.steps,
                        "sync": kenzieDeviceData[0]?.lastSyncTime
                    },
                    "nathan": {
                        "steps": nathan.summary.steps,
                        "sync": nathanDeviceData[0]?.lastSyncTime
                    },
                    "ben": {
                        "steps": ben.summary.steps,
                        "sync": benDeviceData[0]?.lastSyncTime
                    }
                })
            }
        }
        
    } 
    catch (err) {
        console.log(err);
        return err;
    }
};
