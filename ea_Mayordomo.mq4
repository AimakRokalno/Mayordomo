//+-----------------------------------------------------------------+
//|	   		                                        ea_Mayordomo.mq4 |
//|                                          mashup by Aimak Rokalno |
//+------------------------------------------------------------------+
/*
para el futuro
Por ejemplo, ideas para incluir en Mayordomo:

=== ToDo =========
- Usar las GV "MYDM_TradingActivo" para controlar otros EAs
- Que otro EA pueda enviar un mensaje a telegram usando GV con prefijo "MYDM_msg@"+[mensaje]
- cerrar trades desde telegram usando botones
- establecer un beneficio global. Si tienes 10 trades abiertos, el EA puede cerrarlos todos en cuanto el beneficio supere un % o valor determinado
- Mayordomo añade SL de seguridad global. Se me ocurre que el EA cierre todos los trades si el equity es cero, y otro valor
- Mayordomo puede actuar de interruptor general de otros EAs funcionando en el mismo mt4, si están construidos adecuadamente
- Mayordomo puede incuir o gestionar un filtro de noticias


Version 1.0
	- Version inicial. Funcionamiento básico del EA.
	- Envía mensajes al grupo con la información de cada trade abierto
	  cada vez que el EA es cargado en el gráfico y cada FreqMensajes en segundos
	- También envía el Balance, Equity y Freemargin de la cuenta
	- la variable myChat_id está como Long para utilizaa
	- El usuario puede hacer varias acciones usando órdenes pendientes con un lotaje de:
	-- 100 lotes, el EA cerrará todos los trades abiertos del mismo simbolo que la O.Pendiente. No borra otros pendientes
	-- 500 lotes, el EA cerrará todos los trades activos en el terminal
	-- 222 lotes, el EA apagará otros EAs en el mismo terminal (si están creados para ello)
	-- 333 lotes, el EA encenderá otros EAs en el mismo terminal (si están creados para ello)


*/
#property copyright	"Aimak Rokalno en AimakLand "
#property link		"http://www.aimak.com"
#property version	"1.0" 

#property description "EA capacitado para intereactuar en grupo o canal de Telegram."
#property description "Detalles en https://www.mql5.com/en/articles/2355"

#include "stdlib.mqh"
#include "Telegram.mqh"		// Necesario para que funcione enviar mensajes a Telegram

//--- Input parameters
input string 	aaa				= "====== CONF del bot de Telegram ========";	// =================
input int 	 	FreqMensajes	= 3600; 										// Segundos entre acualizaciones periódicas
input string 	MsgTitle		= "Mayordomo Test Bot";							// Titulo de los mensajes del bot
input bool		volcado 		= TRUE;											// Activa volcado de info al registro
input bool		usarTelegrm		= TRUE;											// Activa enviar mensages a Telegram

// definimos myChat_id como Long para utilizar el chat_id numérico. Cambiar a String para usar el nombre del canal/grupo
input long 		myChat_id		= -269973047;							// ID del canal
input string 	myBotToken		= "448849024:AAHRja6QLIcYJCYcKBHgS8bMWe-fHsliqHM";	// Token del bot

input string 	bbb	= "========= Funciones Adicionales =========";		// === Funciones Adicionales
sinput int		MaxIntentosColocacion	= 3;							// Número de intentos para cerrar un trade


//--- Global variables
CCustomBot bot;
int getme_result, crono;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()	{

	//if ( !IsExpertEnabled() || !IsTradeAllowed() || IsOptimization() || IsTesting() ) return( INIT_PARAMETERS_INCORRECT );
	
	   
	//Obtiene segundos desde la última vela H1
	uchar minutos  = (uchar)TimeMinute (TimeCurrent() - iTime( "EURUSD" , PERIOD_H1, 0 ));
	uchar segundos = (uchar)TimeSeconds(TimeCurrent() - iTime( "EURUSD" , PERIOD_H1, 0 ));
	crono = ( 60 * minutos ) + segundos;
	
	//--- set token
	bot.Token(myBotToken);
	
	//--- check token
	getme_result = bot.GetMe();
	
	//--- Creamos cronómetro de función OnTimer() de 1 segundo
	if( !EventSetTimer(1) ) printf( "OnTimer error ", ErrorDescription(GetLastError()));
	
	// Mensaje confirmando activación del EA
	string msg = MsgTitle + " Activo"; 	
	if (volcado) Print( msg ) ;
	if (usarTelegrm) EnviarMsgTelgrm( msg );


	// Primero comprobamos que el interruptor existe, si no lo creamos con valor 0.0=False=Apagado
	GlobalVariableSet( "MYDM_TradingActivo", 1 ); 
		
	
	//--- done 
	return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//|   OnDeInit                                                       |
//+------------------------------------------------------------------+
void OnDeinit( const int reason )	{

	// Borramos los comentarios en el gráfico
	Comment("");
	
	// Matamos el cronómetro
	EventKillTimer();
   	
   	// Mensaje de salida
   	string ExitMsg = getUninitReasonText(_UninitReason);
	string msg = MsgTitle + " desactivado\n" + ExitMsg; 
	
	if (volcado) Print( msg ) ;
	if (usarTelegrm) EnviarMsgTelgrm( msg );

	//--- The second way to get the uninitialization reason code 
	Print(__FUNCTION__," UninitReason = ", ExitMsg);
}

//+------------------------------------------------------------------+
//|   OnTimer                                                        |
//+------------------------------------------------------------------+
void OnTimer()	{

	return;
	
	crono++;
	Comment("Tiempo restante= ", FreqMensajes-crono);

	if( crono >= FreqMensajes )	{
	
		crono=0;
		
		if(( ACCOUNT_BALANCE - ACCOUNT_EQUITY ) == 0 ) return;
		
		for( int i = OrdersTotal() - 1 ; i > 0 ; i-- ) {
	
			if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES )) {
				
				if( OrderType() > 1 ) continue;
				
				double pipos =   (( OrderType() == 0 )? 
							( MarketInfo(OrderSymbol(),MODE_BID) - (OrderOpenPrice()) ) : 
							( OrderOpenPrice() - MarketInfo(OrderSymbol(), MODE_ASK ) )) / MarketInfo( OrderSymbol(), MODE_POINT )/10;
							
				// Podemos usar <i>, <b>, <pre>, <a href> sin anidar
				string msg=	StringFormat("%s \n<pre>Symbol: %s \nType: %s \nPips: %.1f %s</pre>",
						MsgTitle,
						OrderSymbol(),
						( OrderType() == 0 )?"BUY":"SELL",
						pipos,
						( pipos >= 0 )?"\xF600":"\xF62D");
	
						EnviarMsgTelgrm( msg );
			}
			//Sleep(450); // una siestecita entre envíos a Telegram para no saturar
		}
		
		// Enviamos a Telegram el estado de la cuenta
		string msg = StringFormat("Balance= %.2f ; Equity= %.2f ; Freemargin= %.2f", AccountBalance(), AccountEquity(), AccountFreeMargin());
		EnviarMsgTelgrm( msg );
	}
}

  
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void OnTick()	{

	for( int j = GlobalVariablesTotal(); j >= 0; j-- ) {
	
		string _nombreGV = GlobalVariableName(j);
		
		if( StringFind(_nombreGV,"MYDM_msg") == 0 ) {
		
			Print("variable global= ", _nombreGV);
			
			EnviarMsgTelgrm( StringSubstr(_nombreGV,10) );
			
			GlobalVariableDel(_nombreGV);
		}
	}
	
	int Total = OrdersTotal(); // Obtiene número de órdenes activas y pendientes
	
	if( Total > 0 )  {  // Si hay órdenes miramos dentro del pool
	
		for( int i = Total - 1; i>=0; i-- ) {
	
			if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES) ) {
	        
				switch ( (int)OrderLots() ) {
					case 100: {		// Si la orden es de 100 lotes cerramos todas con el mismo simbolo
						string msg = "Orden Pendiente de 100 lotes encontrada";
						if ( volcado ) Print( msg ); 
						if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
						EliminarOrden( OrderTicket() );
						Cerrar1Simbolo( OrderSymbol() );
						break;
					}
					case 222: {
						string msg = "Orden Pendiente de 222 lotes encontrada:\nTRADING DESACTIVADO";
						if ( volcado ) Print( msg ); 
						if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
						EliminarOrden( OrderTicket() );
						GlobalVariableSet( "MYDM_TradingActivo", 0 );
						break;					
					}
					case 333: {
						string msg = "Orden Pendiente de 333 lotes encontrada:\nTRADING ** ACTIVADO **";
						if ( volcado ) Print( msg ); 
						if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
						EliminarOrden( OrderTicket() );
						GlobalVariableSet( "MYDM_TradingActivo", 1 );
						break;
					}
					case 500: {		// Si la orden es de 500 lotes cerramos todas las ordenes
						string msg = "Orden Pendiente de 500 lotes encontrada";
						if ( volcado ) Print( msg ); 
						if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
						CerrarTodos();
						break;
					}
				}
				// Si la orden es menor de 100 lotes es ignorada y continua con la siguiente iteración
			}
		}
	}	
	return;
}

//+------------------------------------------------------------------+ 
//| get text description                                             | 
//+------------------------------------------------------------------+ 
string getUninitReasonText(int reasonCode) 	{ 

	string text=""; 

	switch(reasonCode) 	{ 
		case REASON_ACCOUNT: 
		   text="Account was changed";break; 
		case REASON_CHARTCHANGE: 
		   text="Symbol or timeframe was changed";break; 
		case REASON_CHARTCLOSE: 
		   text="Chart was closed";break; 
		case REASON_PARAMETERS: 
		   text="Input-parameter was changed";break; 
		case REASON_RECOMPILE: 
		   text=__FILE__+" was recompiled";break; 
		case REASON_REMOVE: 
		   text=__FILE__+" was removed from chart";break; 
		case REASON_TEMPLATE: 
		   text="New template was applied to chart";break; 
		default:text="Another reason"; 
	} 
	return(text); 
} 

void EnviarMsgTelgrm ( string _mensaje )	{

	// envía mensaje en formato HTML
	int res = bot.SendMessage( myChat_id, _mensaje ,NULL,true );

	// captura si se produjo error
	if( res != 0 ) Print("Error: ", GetErrorDescription(res) );
	
	return;

}

void Cerrar1Simbolo ( string _Simbolo )	{

	string msg = "Activado CERRAR SOLO LOS TRADES DE " + _Simbolo;
	if ( volcado ) Print( msg ); 
	if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	

	for( int i = OrdersTotal() - 1; i>=0; i--) {

		bool Result=EMPTY;
		if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES) ) {
        
			if ( OrderSymbol() == _Simbolo && OrderType() < 2 ) {	// Solo cierra las órdenes del simbolo actual
	
				// cierra compras activas
				if	  ( OrderType() == OP_BUY ) Result=OrderClose(OrderTicket(),OrderLots(),MarketInfo(_Simbolo,MODE_BID),3,clrNONE); 
				
				// cierra ventas activas
				else if ( OrderType() == OP_SELL ) Result=OrderClose(OrderTicket(),OrderLots(),MarketInfo(_Simbolo,MODE_ASK),3,clrNONE); 
			
				MostrarMsgBorrar( OrderTicket(), Result );
			}
		}
	}
	return;
}

void CerrarTodos()	{

	string msg = "Activado CERRAR TODAS LOS TRADES" ;
	if ( volcado ) Print( msg ); 
	if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	

	for( int i = OrdersTotal() - 1; i>=0; i--) {
	
		bool Result=TRUE;
		
		RefreshRates();
		
		if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES) ) {
	  
			switch ( OrderType() )  {
			
				case OP_BUY: {	// cierra si es BUY
					Result=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_BID),3,clrNONE);
					break;
				}
				case OP_SELL: {	// cierra si es SELL
					Result=OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(),MODE_ASK),3,clrNONE); 
					break;
				}
				default:		// Elimina si es una O.Pendiente
					EliminarOrden( OrderTicket() );
			}
		}
	      MostrarMsgBorrar( OrderTicket(), Result );
	}
	return;
}

void MostrarMsgBorrar ( int _ticket, bool _resultado, string _msg=NULL ) {

      if( _resultado ) {
		double pipos =   (( OrderType() == 0 )? 
					( MarketInfo(OrderSymbol(),MODE_BID) - (OrderOpenPrice()) ) : 
					( OrderOpenPrice() - MarketInfo(OrderSymbol(), MODE_ASK ) )) / Punto(OrderSymbol());

      	string msg = StringFormat ( "Ticket %d cerrado con éxito", _ticket );
      	
      	_msg= StringFormat("\r\n<pre>%s %s@%f pips: %.1f %s</pre>",
      		( OrderType() == 0 )?"BUY":"SELL",
      		OrderSymbol(),
      		OrderOpenPrice(),
      		pipos,
      		(pipos >= 0 )?"\xF600":"\xF62D");
      	
      	
      	if( _msg!=NULL) StringAdd( msg, _msg );
      	
      	if ( volcado ) Print( msg ); 
      	if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
      }
      else {
      	string msg = StringFormat ( "Problema cerrando ticket %d con error: <b>%s</b>", _ticket , ErrorDescription(GetLastError()));

      	_msg= StringFormat("\r\n<pre>Symbol: %s \nType: %s \nPrecio apertura: %.2f \nPrecio actual: %.2f</pre>",
      		OrderSymbol(),
      		( OrderType() == 0 )?"BUY":"SELL",
      		OrderOpenPrice(),
      		( OrderType() == 0 )?MarketInfo(OrderSymbol(),MODE_BID):MarketInfo(OrderSymbol(), MODE_ASK ) );
      	
      	
      	if( _msg!=NULL) StringAdd( msg, _msg );

      	if ( volcado ) Print( msg ); 
      	if ( usarTelegrm ) EnviarMsgTelgrm( msg );	      	
      }
}

// Sustituye y mejora a la función OrderDelete()
void EliminarOrden(int _Ticket, color _ColorFlecha = clrNONE) {
	
	// Variables necesarias
	int _MaxIntentos	= MaxIntentosColocacion;
	bool _Borrada	= false;
	int _CodError	= 0;
	
	if ( !OrderSelect(_Ticket, SELECT_BY_TICKET) ) {
		
		Print("La orden ", _Ticket, " NO EXISTE o ya ha sido ELIMINADA");
		return;
	}
}

// Calcula el valor del punto
double Punto(string _Simbolo = NULL) {
	
	// Si _Simbolo está vacío asignamos el símbolo del gráfico
	ReasignarSimbolo(_Simbolo);
	
	double _PointSimbolo = MarketInfo(_Simbolo, MODE_POINT);
	int _Decimales = (int)MarketInfo(_Simbolo, MODE_DIGITS);
	
	double _Punto = _PointSimbolo * 10;
	
	if ( _Decimales == 2 || _Decimales == 4 ) _Punto = _PointSimbolo;
	else if ( _Decimales == 0 || _Decimales == 1 ) _Punto = 1;
	
	return(_Punto);
}

// Si _Simbolo está vacío asignamos el símbolo del gráfico
void ReasignarSimbolo(string &_Simbolo) {
	
	if ( _Simbolo == NULL ) _Simbolo = _Symbol;
}

				
