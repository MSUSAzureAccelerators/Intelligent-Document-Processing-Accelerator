import React from 'react';

import './Result.css';

export default function Result(props) {
    const imgLocation = `${'https://fsihackstor.blob.core.windows.net/succeeded/'}${props.document.FileName}${'?sp=r&st=2021-09-14T15:49:36Z&se=2022-09-14T23:49:36Z&spr=https&sv=2020-08-04&sr=c&sig=x1GJZNkYePSjsYNRJRohjIIYoFH65LYC1FIOgRq9c5M%3D'}`
    if (props.document.formtype === 'Insurance') {
        return (
        <div className="card result">
            <a href={`/details/${props.document.id}`}>
                
                <img className="card-img-top" src={imgLocation} alt='Insurance'></img>
                <div className="card-body">
                    <h6 className="title-style">Insurance Card</h6>
                </div>
            </a>
        </div>
        )
    } else if (props.document.formtype === 'Driving License') {
        return (
        <div className="card result">
            <a href={`/details/${props.document.id}`}>
                
                <img className="card-img-top" src={imgLocation} alt='Driving License'></img>
                <div className="card-body">
                    <h6 className="title-style">Driving License</h6>
                </div>
            </a>
        </div>
        )
    } else {
    return(
        <div className="card result">
            <a href={`/details/${props.document.id}`}>
                
                <img className="card-img-top" src={imgLocation} alt='Service Estimate'></img>
                <div className="card-body">
                    <h6 className="title-style">Service Estimate</h6>
                </div>
            </a>
        </div>
        );
    }
}
