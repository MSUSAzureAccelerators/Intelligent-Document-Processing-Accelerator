import React, { useState, useEffect } from "react";
import { useParams } from 'react-router-dom';
import CircularProgress from '@material-ui/core/CircularProgress';
import axios from 'axios';

import "./Details.css";

export default function Details() {

  let { id } = useParams();
  const [document, setDocument] = useState({});
  const [selectedTab, setTab] = useState(0);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    setIsLoading(true);
    // console.log(id);
    axios.get('/api/lookup?id=' + id)
      .then(response => {
        const doc = response.data.document;
        console.log(doc)
        setDocument(doc);
        setIsLoading(false);
      })
      .catch(error => {
        console.log(error);
        setIsLoading(false);
      });

  }, [id]);

  // View default is loading with no active tab
  let detailsBody = (<CircularProgress />),
      resultStyle = "nav-link",
      rawStyle    = "nav-link";

  if (!isLoading && document) {
    // View result
    if (selectedTab === 0) {
      resultStyle += " active";
      if (document.formtype === 'Insurance') {
        detailsBody = (
          <div className="card-body">
            <h5 className="card-title">{document.Company}</h5>
            <p className="card-text">{document.Insured} - {document.PolicyNumber}</p>
            <p className="card-text">Make {document.Make} - Model {document.Model} - Year {document.Year}</p>
            <p className="card-text">{document.VIN}</p>
            <p className="card-text">{document.State} State</p>
          </div>
        );
      } else if (document.formtype === 'Driving License') {
        detailsBody = (
          <div className="card-body">
            <h5 className="card-title">{document.FirstName} {document.LastName}</h5>
            <p className="card-text">Document Number - {document.DocumentNumber}</p>
            <p className="card-text">Date of Expiration {document.DateOfExpiration} - DOB {document.DateOfBirth}</p>
            <p className="card-text">Address - {document.Address}</p>
          </div>
        );
      } else {
        detailsBody = (
          <div className="card-body">
            <h5 className="card-title">{document.CustomerName} {document.LastName}</h5>
            <p className="card-text">InvoiceID - {document.InvoiceId} Date - {document.InvoiceDate}</p>
            <p className="card-text">Total {document.InvoiceTotal} - Tax {document.TotalTax}</p>
            <p className="card-text">Vendor - {document.VendorName} Address - {document.VendorAddress}</p>
          </div>
        );
      }
    }

    // View raw data
    else {
      rawStyle += " active";
      detailsBody = (
        <div className="card-body text-left">
          <pre><code>
            {JSON.stringify(document, null, 2)}
          </code></pre>
        </div>
      );
    }
  }

  return (
    <main className="main main--details container fluid">
      <div className="card text-center result-container">
        <div className="card-header">
          <ul className="nav nav-tabs card-header-tabs">
              <li className="nav-item"><button className={resultStyle} onClick={() => setTab(0)}>Result</button></li>
              <li className="nav-item"><button className={rawStyle} onClick={() => setTab(1)}>Raw Data</button></li>
          </ul>
        </div>
        {detailsBody}
      </div>
    </main>
  );
}
