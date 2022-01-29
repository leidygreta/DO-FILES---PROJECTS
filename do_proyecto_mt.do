clear all

global main "C:\Users\Leidy Gongora\Desktop\PROYECTO" 
global bases "$main/BASES"
global work "$main/New"

*===========================================
*******INDICADOR DE POBREZA***********
*===========================================
forvalues j=18/20{
forvalues i=1/4{
use "$bases/enaho01_20`j'_200_`i'.dta", clear
gen time=`j'`i'

}
}

dd
*===========================================
*****INDICADOR DE EMPLEO e INGRESOS*********
*===========================================


*CLASIFICACIÓN DEL PEA Y AGREGAR COLUMNA DE TIEMPO*
forvalues j=18/20{
forvalues i=1/4{
use "$bases/enaho01a_20`j'_500_`i'.dta", clear
gen time=`j'`i'
gen empleado=(ocu500==1)
gen desempleado=(ocu500 > 1 & ocu500 <4)
rename (p524a1) ytot
recode p506r4 ///
(111/322=1   "Agricultura, ganadería, silvicultura y pesca") ///
(510/990=2   "Explotación de minas y canteras") ///
(1010/3320=3 "Industrias manufactureras") ///
(3510/3530=4 "Suministro de electricidad, gas, vapor y aire acondicionado") ///
(3600/3900=5 "Suministro de agua; evacuación de aguas residuales, gestión de desechos y descontaminación") ///
(4100/4390=6 "Construcción") ///
(4510/4799=7 "Comercio al por mayor y al por menor; reparación de vehículos automotores y motocicletas") ///
(4911/5320=8 "Transporte y almacenamiento") ///
(5510/5630=9 "Actividades de alojamiento y servicios de comidas") ///
(5811/6399=10 "Información y comunicaciones") ///
(6411/6630=11 "Actividades financieras y de seguros") ///
(6810/6820=12 "Actividades inmobiliarias") ///
(6910/7500=13 "Actividades profesionales, científicas y técnicas") ///
(7710/8299=14 "Actividades de servicios administrativos y de apoyo") ///
(8411/8430=15 "Administración pública y defensa; planes de seguridad social de afiliación obligatoria") ///
(8510/8550=16 "Enseñanza") ///
(8610/8890=17 "Actividades de atención de la salud humana y de asistencia social") ///
(9000/9329=18 "Actividades artísticas, de entretenimiento y recreativas") ///
(9411/9609=19 "Otras actividades de servicios") ///
(9700/9820=20 "Actividades de los hogares como empleadores; actividades no diferenciadas de los hogares como productores de bienes y servicios para uso propio") ///
(9900/9900=21 "Actividades de organizaciones y órganos extraterritoriales"), gen(sector)
save "$work/empleo_sector20`j'_`i'.dta", replace
}
}


*Unimos las bases
clear all
forvalues j=18/20{
forvalues i=1/4{
append using "$work/empleo_sector20`j'_`i'.dta"
save "$work/empleo_sector.dta", replace
}
}

*AGREGAMOS PROVINCIA
use "$bases/ENAHO-TABLA-UBIGEO.dta", clear
merge 1:m ubigeo using "$work/empleo_sector.dta", nogen
save "$work/modulo5.dta", replace

***indicadores***
use "$work/modulo5.dta", clear 
preserve
collapse (sum)empleado (sum)desempleado (mean)ytot [iw=fac500], by (time provincia)
gen lnempl=ln(empleado) 
gen lny=ln(ytot)
save "$work/indicadores.dta", replace
restore

*===========================================
*****SC PARA LA PROVINCIA *********
*===========================================
use "$work/indicadores.dta", clear
recode time (181=1) (182=2) (183=3) (184=4) (191=5) (192=6) (193=7) (194=8) (201=9) (202=10) (203=11) (204=12), gen (t)
encode provincia, gen(id)
order id 
drop provincia
xtset id t

*COMO TENGO UN PANEL NO BALANCEADO, ELIMINARÉ ALGUNAS PROVINCIAS QUE NO TENGA INFORMACIÓN PARA TODOS LOS AÑOS
egen wanted = total(inrange(t, 1, 12)), by(id)
keep if wanted==12
*CORROBORAMOS QUE TENEMOS UN PANEL BALANCEADO
xtset id t
***Me quedo 132/196 provincias

***Comparemos la provincia tratada con el promedio simple de los otras provincias

*EMPLEO
preserve
gen group=(id==1)
tab id group
collapse (mean) lnempl, by (group t)
quietly: reshape wide lnempl, i(t) j(group)
tsline lnempl0 lnempl1, xline(10)
restore

*INGRESO
preserve
gen group=(id==1)
tab id group
collapse (mean) lny, by (group t)
quietly: reshape wide lny, i(t) j(group)
tsline lny0 lny1, xline(10)
restore

**Ahora el comando para el sacar el mejor promedio de mis controles

synth lnempl lny lnempl(1) lny(5(1)9) lnempl(8) lnempl(9), trunit(1) trperiod(10) nested

***
preserve
keep id t lnempl
keep if id==1
rename lnempl lnempl_abancay

matrix lnempl_scm=e(Y_synthetic)
svmat lnempl_scm
list

tsline lnempl_abancay lnempl_scm, xline(10)
*TREATMENT EFFECT
gen te=lnempl_abancay - lnempl_scm

tsline te, ylabel(-2(2)2) yscale(range(-5 5)) xline(10) yline(0)
restore


**PLACEBO***
***Asiganamos el tratamiento a cada uno de los controles. En cada iteración, cambio mi unidad tratada
macro drop rmspe_names synth_names
levelsof id, local(id_codes_list)
local i=1
foreach id_code of local id_codes_list {
    display _n(1) as result "Provincia `id_code' (iteration `i')"
	quietly: synth lnempl lny lnempl(1) lny(5(1)9) lnempl(8) lnempl(9), trunit(1) trperiod(10) nested
    
	if `i'==1 	{	//for the first iteration, it just creates the vectors separately
		matrix rmspe 	= e(RMSPE) //guardo mspe para el pre traetment
		matrix y_synth 	= e(Y_synthetic)
		matrix y_obs   	= e(Y_treated)

	}
	else 	{		//for the next iterations, we put the vectors (separately) next to the previous ones
	    matrix rmspe 	= rmspe \ e(RMSPE)
		matrix y_synth 	= y_synth, e(Y_synthetic)	
		matrix y_obs 	= y_obs, e(Y_treated)	
	}
	global rmspe_names ${rmspe_names} `id_code'
	global synth_names ${synth_names} "synth_`id_code'"
	
	matrix list rmspe		//just to see how the accumulation process works, comment out once you actually understand it
	matrix list y_synth
	matrix list y_obs
	more
	
	local ++i
}

*Nombramiento de las matrices de información
mat colnames rmspe = "RMSPE"
mat rownames rmspe = ${rmspe_names}
matrix list rmspe

mat colnames y_synth = ${synth_names}
matrix list y_synth
mat colnames y_obs = ${synth_names}
matrix list y_obs
*Efecto tratamiento para cada uno de las provincias tratadas
matrix te= y_obs - y_synth

***Imprimo como un dta todas los te de las variables 
preserve
drop _all
svmat2 te, names(col) rnames(year)
renvars synth_1-synth_39, subst("synth" "te")
destring t, replace
order t, first
save "$work/efectotratamiento.dta", replace
tsset t
#delimit;
graph twoway 
(tsline te_?, lcolor(gs12 ..) lpattern(solid) lwidth(thin))
(tsline te_1?, lcolor(gs12 ..) lpattern(solid) lwidth(thin))
(tsline te_2?, lcolor(gs12 ..) lpattern(solid) lwidth(thin))			
(tsline te_3?, lcolor(gs12 ..) lpattern(solid) lwidth(thin))			
(tsline te_3, lcolor(red) lpattern(solid) lwidth(medthick)),
ytitle("") ylabel(, angle(0) format(%5.2fc) labsize(medsmall) nogrid) yline(0, lpattern(solid) lcolor(black))
xtitle("") xlabel(1(4)12, labsize(medsmall) nogrid) xmtick(1(4)12) 
xline(12, lwidth(medthick) lcolor(red) lpattern(dash))
subtitle("Efecto Tratamiento", tstyle(subheading) margin(b=2))
legend(off) 
graphregion(fcolor(white)) plotregion(margin(zero) lcolor(black))
/*nodraw*/;
#delimit cr

restore
















02:24:46


restore

***INGRESO

**Ahora el comando para el sacar el mejor promedio de mis controles
synth lny lnempl lnempl(5(1)9), trunit(1) trperiod(10) nested













yscale(range(0 140)) 








synth empleado empleado(20193 20194) ytot, trunit(1) trperiod(20201) nested





reshape wide empleado desempleado ytot, i(id) j(periodo)





gen nperiod=[_N]
keep if nperiod==3






















