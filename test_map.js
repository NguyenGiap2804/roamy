const https = require('https');
https.get('https://www.google.com/maps/place/Th%E1%BB%81m+Cafe/@21.0238742,105.5663372,16.55z', (res) => {
  let data = '';
  res.on('data', d => data += d);
  res.on('end', () => {
    const titleMatch = data.match(/<meta property="og:title" content="(.*?)"/);
    const descMatch = data.match(/<meta property="og:description" content="(.*?)"/);
    console.log("Title: ", titleMatch ? titleMatch[1] : 'No title');
    console.log("Desc: ", descMatch ? descMatch[1] : 'No desc');
  });
});
