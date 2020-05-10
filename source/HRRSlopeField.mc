using Toybox.Application as App;
using Toybox.WatchUi as Ui;
using Toybox.Graphics as Graphics;
using Toybox.System as System;

const BORDER_PAD = 4;
const UNITS_SPACING = 2;
const TOP_PAD = 10;
const NUMBER_CELLS = 5;

const DEBUGGING = true;
enum {
	eStartingState, eSeekingState, eMeasuringState
}

var fonts = [Graphics.FONT_XTINY,Graphics.FONT_TINY,Graphics.FONT_SMALL,Graphics.FONT_MEDIUM,Graphics.FONT_LARGE,
             Graphics.FONT_NUMBER_MILD,Graphics.FONT_NUMBER_MEDIUM,Graphics.FONT_NUMBER_HOT,Graphics.FONT_NUMBER_THAI_HOT];

class YlayoutBlock {
	//space for border, the app name and then status field
	var mStartTitleY;
	var mTitleFont;
	var mStartStatusY;
	var mStatusFont;
	//area for results starts here with a row for headers
	var mStartResHeaderY;
	//then two further blocks for 
	var mStartResLatestY;
	var mStartResFinalY;
	var mResFont;
	//field at bottom for scaore and border
	var mStartScoreY;
	var mScoreFont;
	//ON FONT will need to test Y and X sizes!!

	function initialise() {
		mTitleFont = Graphics.FONT_TINY;
		mStatusFont= Graphics.FONT_TINY;
		mResFont= Graphics.FONT_TINY;
		mScoreFont = Graphics.FONT_TINY;
	}
}

class XlayoutBlock {
	//horizontal structure
	//Title is assumed to be put in middle
	//Status is offset
	var mStatusStartX;
	var mScoreStartX;
	// each row has (label, T10,20,30,60,120)
	// we could calculate these on draw as fixed offset
	var mStartLabelX;
	var aStartDataCells = new [NUMBER_CELLS];
	// this is width of each datacell
	var mStartTWidthX;

	function initialise() {
	}
}

class HRRSlopeView extends Ui.DataField {

    hidden var YaxisLayout = new YlayoutBlock();
    hidden var XaxisLayout = new XlayoutBlock();
    
    hidden var mTitleString = Ui.loadResource(Rez.Strings.lAppTitleLine);
    hidden var mSeekString = Ui.loadResource(Rez.Strings.lMeasssageSeek);
    hidden var mMeasureString = Ui.loadResource(Rez.Strings.lMessageMeasure);
    hidden var mStartString = Ui.loadResource(Rez.Strings.lStartingSearch);
    hidden var mScoreString = Ui.loadResource(Rez.Strings.lMessageScore);
    
    hidden var mSearchState = eStartingState;
    
    // Font values
    hidden var mDataFontAscent;
    hidden var mLabelFontAscent;

    // field separator line
    hidden var separator;

    hidden var xCenter;
    hidden var yCenter;
    
    hidden var mFitContributor;
    hidden var mSensor;
    hidden var mSensorFound;
    hidden var mSensorConnected;
    hidden var mTicker;
    
    // variables for data fields
    hidden var mMeasureTimer;
    hidden var aTvalueHeaders = ["10", "20", "30", "60", "120"];
    hidden var aLatestTvalues = new [NUMBER_CELLS ];
    hidden var aFinalTvalues = new [NUMBER_CELLS ];
    
    function initialize(sensor) {
        DataField.initialize();
        mSensor = sensor;
        mFitContributor = new AuxHRFitContributor(self);
		mTicker = 0;
		mSensorFound = false;
		mSensorConnected = false;
		mMeasureTimer = 0;
		for( var i = 0; i < aTvalueHeaders.size(); i += 1 ) {
    		aLatestTvalues[i] = "---";
		}
		for( var i = 0; i < aTvalueHeaders.size(); i += 1 ) {
    		aFinalTvalues[i] = "---";
		}
    }
    
	function selectFont(dc, width, height, testString) {
        var fontIdx;
        var dimensions;

        //Search through fonts from biggest to smallest
        for (fontIdx = (fonts.size() - 1); fontIdx > 0; fontIdx--) {
            dimensions = dc.getTextDimensions(testString, fonts[fontIdx]);
            if ((dimensions[0] <= width) && (dimensions[1] <= height)) {
                //If this font fits, it is the biggest one that does
                break;
            }
        }

        return fontIdx;
    } 

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
        var width = dc.getWidth();
        var height = dc.getHeight();

        var vLayoutWidth;
        var vLayoutHeight;
        var vLayoutFontIdx;
        var vLayoutTitleStatusHeight;
        var vLayoutResHeight;
        var vLayoutCellWidth;
   
	    var top = TOP_PAD + BORDER_PAD;

		System.println( "Layout started");
		
		// Compute data width/height for vertical layouts
		// note as this is a circle then the actual width will be less at the top etc
		// might need a side pad
        vLayoutWidth = width - (2 * BORDER_PAD);
        // calculate total height after TOP and PAD
        vLayoutHeight = height - top * 2 - 2 * BORDER_PAD;
        
        //20% for top
        vLayoutTitleStatusHeight = vLayoutHeight * 2 / 10;
        //50% for data
        vLayoutResHeight = vLayoutHeight * 5 / 10 ;
        vLayoutCellWidth = vLayoutWidth / 6;
        
        // Note dc.drawtext references location of x,y 
        // hence we want to adjust X and Y by half dimension of cell they are in
        YaxisLayout.mStartScoreY = (top + vLayoutTitleStatusHeight + vLayoutResHeight);
        YaxisLayout.mStartScoreY = YaxisLayout.mStartScoreY + (vLayoutHeight - YaxisLayout.mStartScoreY) / 2; 
              
		//values to work out
		YaxisLayout.mStartTitleY = top + vLayoutTitleStatusHeight / 4;
		YaxisLayout.mStartStatusY = YaxisLayout.mStartTitleY + vLayoutTitleStatusHeight / 2;
		
		// test font for tite and status
		vLayoutFontIdx = selectFont(dc, vLayoutWidth, vLayoutTitleStatusHeight/2, mTitleString);
		YaxisLayout.mTitleFont = fonts[vLayoutFontIdx];
		
        vLayoutFontIdx = selectFont(dc, vLayoutWidth, vLayoutTitleStatusHeight/2, mMeasureString+"000");
		YaxisLayout.mStatusFont = fonts[vLayoutFontIdx];

        vLayoutFontIdx = selectFont(dc, vLayoutWidth, vLayoutTitleStatusHeight/2, mScoreString+"000");
		YaxisLayout.mScoreFont = fonts[vLayoutFontIdx];
		
		// now work out space to Results. These include border padding
		// offset half way into cell
		YaxisLayout.mStartResHeaderY = top+vLayoutTitleStatusHeight + vLayoutResHeight/6;
		YaxisLayout.mStartResLatestY = YaxisLayout.mStartResHeaderY + vLayoutResHeight/3;
		YaxisLayout.mStartResFinalY = YaxisLayout.mStartResLatestY + vLayoutResHeight/3;
			
		// same for X
		// Offset Name and status Strings from left
		XaxisLayout.mStatusStartX = TOP_PAD + vLayoutWidth / 2;
		XaxisLayout.mScoreStartX = XaxisLayout.mStatusStartX;
		
		// Also same for data label
		XaxisLayout.mStartLabelX = TOP_PAD + vLayoutCellWidth / 2;
		
		// width of each cell on display
		XaxisLayout.mStartTWidthX = vLayoutCellWidth;
		
		// what fits in X buckets. Note value not bigger than 3 digits but add one place for spacing
		// removed BORDER_PAD from x and y for now as text placed in centre
		vLayoutFontIdx = selectFont(dc, vLayoutResHeight/3, XaxisLayout.mStartTWidthX, "0000");
		YaxisLayout.mResFont = fonts[vLayoutFontIdx];
				
		for( var i = 0; i < XaxisLayout.aStartDataCells.size(); i += 1 ) {
    		if (i==0) {
    			// offset into middle of first cell
    			XaxisLayout.aStartDataCells[i] = XaxisLayout.mStartLabelX + XaxisLayout.mStartTWidthX /2;
    		} else {
    			XaxisLayout.aStartDataCells[i] = XaxisLayout.aStartDataCells[i-1] + XaxisLayout.mStartTWidthX;
			}
		}

		mDataFontAscent = Graphics.getFontAscent(YaxisLayout.mResFont);
        mLabelFontAscent = Graphics.getFontAscent(YaxisLayout.mStatusFont);
        
        // NEED TO ADD BORDER PAD TO X and Y values
        // HERE
        
    	// Might need to deduct mDataFontAscent/2 from Y position on each row and border at top
    	// Y-> Y + BORDER_PAD - (mDataFontAscent/2)
    	// and for Label ascent as well
         
        // print out debug info
        if (true == DEBUGGING) {
        	System.println( "vLayoutwidth " + vLayoutWidth);
        	System.println( "vLayoutheight " + vLayoutHeight);
        	System.println( "vLayoutFont ID " + vLayoutFontIdx);
        	
        	System.println( " mStartTitleY " + YaxisLayout.mStartTitleY);
			System.println( " mTitleFont " + YaxisLayout.mTitleFont );
			System.println( " mStartStatusY "  + YaxisLayout.mStartStatusY);
			System.println( " mStatusFont " + YaxisLayout.mStatusFont);
			System.println( " mStartResHeaderY " + YaxisLayout.mStartResHeaderY);
			System.println( " mStartResLatestY " + YaxisLayout.mStartResLatestY );
			System.println( " mStartResFinalY " + YaxisLayout.mStartResFinalY );
			System.println( " mResFont " + YaxisLayout.mResFont);
			System.println( " mStartScoreY " + YaxisLayout.mStartScoreY);	  
			
			System.println( " mStatusStartX " + XaxisLayout.mStatusStartX );
			System.println( " mStartLabelX " + XaxisLayout.mStartLabelX);
			System.println( " mStartDataCell10X " + XaxisLayout.aStartDataCells[0]);
			System.println( " mStartDataCell20X " + XaxisLayout.aStartDataCells[1]);
			System.println( " mStartDataCell30X " + XaxisLayout.aStartDataCells[2]);
			System.println( " mStartDataCell60X " + XaxisLayout.aStartDataCells[3]);
			System.println( " mStartDataCell120X " + XaxisLayout.aStartDataCells[4]);
			System.println( " mStartTWidthX " + XaxisLayout.mStartTWidthX);      
        } 
            
        // Do not use a separator line for vertical layout
        separator = null;

        xCenter = dc.getWidth() / 2;
        yCenter = dc.getHeight() / 2;
		System.println("Field layout done"); 
    }

    // The given info object contains all the current workout information.
    // Calculate a value and save it locally in this method.
    // Note that compute() and onUpdate() are asynchronous, and there is no
    // guarantee that compute() will be called before onUpdate().  
    function compute(info) {
        // See Activity.Info in the documentation for available information.
        if(info has :currentHeartRate){
            if(info.currentHeartRate != null){
                mSensor.data.OHRHeartRate = info.currentHeartRate;
            } else {
                mSensor.data.OHRHeartRate = null;
            }
        }
        
        // old code
    	var dAuxHeartRate;
        if  (mSensor.data.currentHeartRate == null) {
        	dAuxHeartRate = "--";
        } else {
        	dAuxHeartRate = mSensor.data.currentHeartRate.format("%.0u");
        }
		
		var dOHRHeartRateDelta; 
		if  (mSensor.data.OHRHeartRateDelta == null) {
        	dOHRHeartRateDelta = "--";
        } else {
        	dOHRHeartRateDelta = mSensor.data.OHRHeartRateDelta.format("%+.0i");
        }
		
		var dOHRHeartRate; 
		if  (mSensor.data.OHRHeartRate == null) {
        	dOHRHeartRate = "--";
        } else {
        	dOHRHeartRate = mSensor.data.OHRHeartRate.format("%.0u");
        }
        // end OLD code
    
    	// push data to fit file and calc delta
        mFitContributor.compute(mSensor);
   	}
   
	function manageSensor(dc) {
		var mStartDataCollection = false;
	 	
	 	// don't force skip of this function if data collection started as possible to lose sensor connection  	
	   	// force debug and skip sensor search
	   	if (DEBUGGING) {
	    	mSensorFound = true;
	    	mTicker =6;
	    	mSensor.searching = false;
	    	mSensor.data.currentHeartRate = 100;
	    }
	
	    // Update status
	    if (mSensor == null) {
	        dc.drawText(xCenter, yCenter-50, Graphics.FONT_MEDIUM, "No Channel!", Graphics.TEXT_JUSTIFY_CENTER);
	        mSensorFound = false;
	        System.println("state msensor null");
	    } else if (true == mSensor.searching) {
	        dc.drawText(xCenter, yCenter-50, Graphics.FONT_MEDIUM, "Searching...", Graphics.TEXT_JUSTIFY_CENTER);
	        mSensorFound = false;
	        System.println("state searching");
	    	} else {    
		    	if (!mSensorFound) {
		            mSensorFound = true;
		            mTicker = 0;
		        }
	        
		        if (mSensorFound && mTicker < 5) {
		            var auxHRAntID = mSensor.deviceCfg.deviceNumber;
		            mTicker++;
		            dc.drawText(xCenter, yCenter-50, Graphics.FONT_MEDIUM, "Found " + auxHRAntID, Graphics.TEXT_JUSTIFY_CENTER);
		        } else {
	        		// found sensor, connected and ready to take measurements
	        		mStartDataCollection = true;
	        	}
	   		}
		return mStartDataCollection;
	}
 
	// Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
    	var mStateString = "";
        var bgColor = getBackgroundColor();
        var fgColor = Graphics.COLOR_WHITE;

        if (bgColor == Graphics.COLOR_WHITE) {
            fgColor = Graphics.COLOR_BLACK;
        }

        System.println("onUpdate Field started");
        dc.setColor(Graphics.COLOR_TRANSPARENT, bgColor);
        dc.clear();

        dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
        
        // force debug and skip sensor search
        if (DEBUGGING) {
        	mSensorFound = true;
        	mTicker =6;
        	mSensor.searching = false;
        	mSensor.data.currentHeartRate = 100;
        }

        if (true == manageSensor(dc)) {
	    	// need to draw all data elements
	    	System.println("Entered text draw of field");
	    	// show app name
	    	dc.setColor( Graphics.COLOR_DK_BLUE, Graphics.COLOR_TRANSPARENT);
	    	dc.drawText(XaxisLayout.mStatusStartX, YaxisLayout.mStartTitleY, YaxisLayout.mTitleFont, mTitleString, Graphics.TEXT_JUSTIFY_VCENTER | Graphics.TEXT_JUSTIFY_CENTER);
	    	dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
					
           	switch (mSearchState) {	            
            	case eMeasuringState:
            		// need to add time measure as well to end of string
            		mStateString = mMeasureString + " " + mMeasureTimer.format("%i");
            		break;
            	case eSeekingState:
            		mStateString = mSeekString;
            		break;
            	case eStartingState:
            		mStateString = mStartString;
            		break;
            	default:
            		// shouldn't come here
            		mStateString = "Whoops";
            		System.println("mSearchState default case");
            		break;
            }
            dc.drawText(XaxisLayout.mStatusStartX, YaxisLayout.mStartStatusY, YaxisLayout.mStatusFont, mStateString, Graphics.TEXT_JUSTIFY_CENTER);
         
            // now we need to draw table headers
            // columns 1st
       		dc.drawText(XaxisLayout.mStartLabelX, YaxisLayout.mStartResHeaderY, YaxisLayout.mResFont, "T", Graphics.TEXT_JUSTIFY_CENTER);
       		dc.drawText(XaxisLayout.mStartLabelX, YaxisLayout.mStartResLatestY, YaxisLayout.mResFont, "L", Graphics.TEXT_JUSTIFY_CENTER);
       		dc.drawText(XaxisLayout.mStartLabelX, YaxisLayout.mStartResFinalY, YaxisLayout.mResFont, "F", Graphics.TEXT_JUSTIFY_CENTER);
      		
       		// now need to draw rows
       		for( var i = 0; i < aTvalueHeaders.size(); i += 1 ) {
       			dc.drawText(XaxisLayout.aStartDataCells[i], YaxisLayout.mStartResHeaderY, YaxisLayout.mResFont, aTvalueHeaders[i], Graphics.TEXT_JUSTIFY_CENTER);
    			dc.drawText(XaxisLayout.aStartDataCells[i], YaxisLayout.mStartResLatestY, YaxisLayout.mResFont, aLatestTvalues[i], Graphics.TEXT_JUSTIFY_CENTER);
    			dc.drawText(XaxisLayout.aStartDataCells[i], YaxisLayout.mStartResFinalY, YaxisLayout.mResFont, aFinalTvalues[i], Graphics.TEXT_JUSTIFY_CENTER);
			}
            
	      	// bottom has comment or overall score
	      	// need to add string!!!
	      	dc.setColor( Graphics.COLOR_DK_GREEN, Graphics.COLOR_TRANSPARENT);
       		dc.drawText(XaxisLayout.mScoreStartX, YaxisLayout.mStartScoreY, YaxisLayout.mScoreFont, mScoreString+"0", Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);  
                	
            if (separator != null) {
                dc.setColor(fgColor, fgColor);
                dc.drawLine(separator[0], separator[1], separator[2], separator[3]);
            }
	    }
        // Call parent's onUpdate(dc) to redraw the layout ONLY if using layouts!
        //View.onUpdate(dc);
 		System.println("redraw field complete");
    }
    
    function onTimerStart() {
        mFitContributor.setTimerRunning( true );
    }

    function onTimerStop() {
        mFitContributor.setTimerRunning( false );
    }

    function onTimerPause() {
        mFitContributor.setTimerRunning( false );
    }

    function onTimerResume() {
        mFitContributor.setTimerRunning( true );
    }

    function onTimerLap() {
        mFitContributor.onTimerLap();
    }

    function onTimerReset() {
        mFitContributor.onTimerReset();
    }

}
