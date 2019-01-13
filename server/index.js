const express = require('express');
const session = require('express-session');
const app = express();
const bodyParser = require('body-parser');
const cors = require('cors')
const request = require('request')

const path = require('path')
const PORT = process.env.PORT || 5000

app.use(cors())
app.use(bodyParser.urlencoded({
   extended: false,
   limit: '5mb'
}));
app.use(bodyParser.json({
   limit: '5mb'
}));

const googleCloudUrl = `https://vision.googleapis.com/v1/images:annotate?key=AIzaSyD7Dk3JNdXWqBzdbqaKiUKHngl9VXCrwVE`;
const discoverApiKey = 'l7xx53cc38b255db41fe99238e385c2f39bf';

const bearer =  'Bearer 55a592c9-2c45-46f3-b308-b46ed450aa32'

const countryToCurrencyCode = {
   'United States': 'USD',
   'Mexico': 'MXN',
   'Canada': 'CAD',
   'Germany': 'EUR',
   'United Kingdom': 'GBP',
}

const countryToDiscoverCode = {
   'United States': '310',
   'Mexico': '334',
   'Canada': '302',
   'Germany': '262',
   'United Kingdom': '234',
}

app.get('/', (req, res) => {
   res.send({'hello': 'its me!'})
})

app.post('/api/image', (req, res) => {

   const country = req.body.country;
   const tipType = req.body.tipType;
   console.log(country)
   var options = {
      method: 'POST',
      url: 'https://vision.googleapis.com/v1/images:annotate',
      qs: {
         key: 'AIzaSyD7Dk3JNdXWqBzdbqaKiUKHngl9VXCrwVE'
      },
      headers: {
         'Postman-Token': 'a5b72c06-98fc-406c-90a1-031bf131b112',
         'cache-control': 'no-cache',
         'Content-Type': 'application/json'
      },
      body: {
         requests: [{
            image: {
               content: req.body.image
            },
            features: [{
               type: 'TEXT_DETECTION',
               maxResults: 1
            }]
         }]
      },
      json: true
   };


   /*
    *
      Google Cloud request
    *
   */
   request(options, function(googleError, googleResponse, googleBody) {
      if (googleError) throw new Error(googleError);

      const output = googleBody.responses[0].fullTextAnnotation.text;
      const text = output.split(' ').slice(0, -1).join(' ');
      const price = output.replace(/(\r\n\t|\n|\r\t)/gm, '').split(' ')[output.split(' ').length - 1];
      // const priceNumbersOnly = price.substring(1, price.length);
      const priceNumbersOnly = output.match(/\d/g).join('');
      console.log('items split by space:' + output.split(' '))
      console.log('text:' + text);
      console.log('price:' + price)
      console.log('price no sign:' + priceNumbersOnly)


      /*
         Currency Converter request
         */
      const currencyOptions = {
         method: 'GET',
         url: `https://api.discover.com/dci/currencyconversion/v1/exchangerate?currencycd=${countryToCurrencyCode[country]}`,
         headers: {
            'Postman-Token': 'de330e95-0af9-4655-afee-8de42453d962',
            'cache-control': 'no-cache',
            Authorization: bearer,
            'X-DFS-API-PLAN': 'DCI_CURRENCYCONVERSION_SANDBOX',
            'Content-Type': 'application/json',
            Accept: 'application/json'
         }
      };

      request(currencyOptions, (currencyError, currencResponse, currencyBody) => {
         if (currencyError) throw new Error(currencyError);

         // console.log('currency body:' + currencyBody);

         const exchangeRate = JSON.parse(currencyBody).exchange_rate;
         console.log(exchangeRate)

         console.log('exhange rate:' + exchangeRate)
         const currency = JSON.parse(currencyBody).curr_cd;
         const convertedAmount = priceNumbersOnly * exchangeRate;
         console.log(`${exchangeRate} * ${priceNumbersOnly} =  ${exchangeRate * priceNumbersOnly}`)



         // console.log('Status', response.statusCode);
         // console.log('Headers', JSON.stringify(response.headers));
         // console.log('Reponse received', body);
         // res.send('u')


         const tipUrl = 'https://api.discover.com/dci/tip/v1/guide';
         const tipQueryParams = '?' + encodeURIComponent('countryisonum') + '=' + encodeURIComponent(countryToDiscoverCode[country]);
         request({
            url: tipUrl + tipQueryParams,
            headers: {
               'Accept': 'application/json',
               'x-dfs-api-plan': 'DCI_TIPETIQUETTE_SANDBOX',
               'Authorization': bearer
            },
            method: 'GET'
         }, (tipError, tipResponse, tipBody) => {
            tipBody = JSON.parse(tipBody);
            // console.log(tipBody)
            // res.send(tipBody)
            if (tipBody instanceof Array) {
               const tipInfo = tipBody.filter(x => x.tipCategoryDesc == tipType)[0];


               const defaultTipAmount = tipInfo.defaultTipAmount;
               const tipDescription = tipInfo.tipDescription;

               let complies = 'true'
               console.log('text:' + text);
               if (text.toLowerCase().includes('vodka')) {
                  complies = 'false'
               }

               if (convertedAmount + defaultTipAmount > 100) {
                  complies = 'false'
               }
               res.send({
                  defaultTipAmount: defaultTipAmount,
                  tipDescription: tipDescription,
                  convertedAmount: `${Math.round((convertedAmount + defaultTipAmount) * 100) / 100}`,
                  item: text,
                  original_currency: currency,
                  complies: complies
               })
            } else {
               res.send({
                  defaultTipAmount: defaultTipAmount,
                  tipDescription: tipDescription,
                  convertedAmount: `${Math.round((convertedAmount + defaultTipAmount) * 100) / 100}`,
                  item: text,
                  original_currency: currency,
                  complies: 'true'
               })
            }

         });
      });




   });


})

app.listen(PORT, () => console.log(`Listening on ${ PORT }`))
